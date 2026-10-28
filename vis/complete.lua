-- complete.lua: fuzzy, automatic word completion for the vis editor
--
-- Modelled on Neovim's  completeopt=menuone,noselect,popup,fuzzy  +  autocomplete
--
--   * candidates : words of the current buffer
--   * matching   : fuzzy (subsequence + scoring: word boundaries, camelCase,
--                  consecutive runs, prefix bonus, frequency)
--   * automatic  : the candidate list updates while you type (insert mode)
--   * noselect   : nothing is inserted until you ask for it
--   * <Tab> / <S-Tab> cycle through candidates, replacing the typed word;
--     cycling past the last one returns to what you originally typed
--   * <C-e> cancels (restores the typed text), <C-y> accepts
--   * with no candidates, <Tab> / <S-Tab> behave exactly as before
--
-- vis has no popup widget, so the "popup" is drawn in the window's status bar.
--
-- Install:  copy to ~/.config/vis/complete.lua and put this in visrc.lua
--
--     require("complete").setup()
--
-- Options (all optional):
--
--     require("complete").setup{ min_chars = 1, max_items = 10 }
--
-- Command:  :complete [on|off]   (no argument toggles)
--
-- Written to run on Lua 5.1 - 5.4 / LuaJIT (no goto, no //, no utf8 library).

local M = {
	enabled      = true,
	min_chars    = 2,        -- typed characters needed before candidates appear
	min_word_len = 3,        -- shorter words are never offered as candidates
	max_word_len = 64,       -- longer ones (hashes, base64, minified blobs) are ignored
	max_items    = 8,        -- candidates kept / shown
	max_scan     = 262144,   -- bytes scanned for words; larger files: window around cursor
	rescan_drift = 128,      -- rescan when the file size drifted this much since last scan
	mappings = {
		{ key = "<Tab>",   action = "next",   fallback = "<vis-insert-tab>" },
		{ key = "<S-Tab>", action = "prev",   fallback = "<vis-selections-align-indent-left>" },
		{ key = "<C-e>",   action = "cancel", fallback = "<vis-motion-line-end>" },
		{ key = "<C-y>",   action = "accept" },
	},
}

local WORD_CHAR = "[%w_\128-\255]"
local WORD_RUN  = WORD_CHAR .. "+"
local WORD_END  = WORD_CHAR .. "*$"

------------------------------------------------------------------------------
-- Word index (per file)
------------------------------------------------------------------------------

local indexes = setmetatable({}, { __mode = "k" })   -- file -> index

local function new_index(size)
	return { count = {}, list = {}, lower = {}, meta = {}, size = size or 0, version = 0 }
end

local function index_add(ix, word)
	local c = ix.count[word]
	if c then
		ix.count[word] = c + 1
		return
	end
	ix.count[word] = 1
	ix.list[#ix.list + 1] = word
	ix.lower[word] = word:lower()
	ix.version = ix.version + 1
end

local function usable_word(w)
	return #w >= M.min_word_len and #w <= M.max_word_len and not w:find("^%d")
end

-- Collect the words of `file`. The word the cursor is in (at 0-based `pos`)
-- is left out: it is what is being typed, not a candidate.
local function scan(file, pos)
	local size = file.size
	local from, len = 0, size
	if size > M.max_scan then
		len  = M.max_scan
		from = math.max(0, math.min(pos - math.floor(len / 2), size - len))
	end
	local text = (len > 0 and file:content(from, len)) or ""
	local ix = new_index(size)
	local cur = pos - from + 1                 -- 1-based index of the byte after the cursor
	local cut_head, cut_tail = from > 0, from + len < size
	local text_end = #text + 1
	for s, w, e in text:gmatch("()(" .. WORD_RUN .. ")()") do
		local partial = (cut_head and s == 1) or (cut_tail and e == text_end)
		if not partial and usable_word(w) and not (s <= cur and cur <= e) then
			index_add(ix, w)
		end
	end
	return ix
end

local function get_index(file, pos)
	local ix = indexes[file]
	if not ix or math.abs(file.size - ix.size) > M.rescan_drift then
		ix = scan(file, pos)
		indexes[file] = ix
	end
	return ix
end

------------------------------------------------------------------------------
-- Fuzzy matching
------------------------------------------------------------------------------

local MATCH, GAP_START, GAP_EXT = 16, -3, -1
local B_BOUNDARY, B_CAMEL, B_DIGIT, B_CONSEC = 8, 7, 4, 4
local PREFIX_BONUS, PREFIX_CASE_BONUS = 40, 20
local NEG, VALID = -1e9, -1e8

local function is_lower(b) return b >= 97 and b <= 122 end
local function is_upper(b) return b >= 65 and b <= 90 end
local function is_digit(b) return b >= 48 and b <= 57 end
local function is_alnum(b) return is_lower(b) or is_upper(b) or is_digit(b) or b >= 128 end

local row_a, row_b = {}, {}   -- scratch DP rows, reused between calls

-- Per-word data (lowercase bytes + position bonuses), built lazily and cached.
local function word_meta(ix, w, lw)
	local meta = ix.meta[w]
	if meta then return meta end
	local n = #lw
	local lb = { lw:byte(1, n) }
	local ob = { w:byte(1, n) }
	local bon = {}
	for j = 1, n do
		local b = 0
		if j == 1 then
			b = B_BOUNDARY
		else
			local p, c = ob[j - 1], ob[j]
			if not is_alnum(p) then
				b = B_BOUNDARY
			elseif is_lower(p) and is_upper(c) then
				b = B_CAMEL
			elseif not is_digit(p) and is_digit(c) then
				b = B_DIGIT
			end
		end
		bon[j] = b
	end
	meta = { lb = lb, bon = bon }
	ix.meta[w] = meta
	return meta
end

-- Greedy left-to-right subsequence test: cheap pre-filter before scoring.
local function is_subsequence(pchars, m, lw)
	local pos = 1
	for i = 1, m do
		pos = lw:find(pchars[i], pos, true)
		if not pos then return false end
		pos = pos + 1
	end
	return true
end

-- Best alignment of the pattern inside the word (small Smith-Waterman style
-- DP, O(#pattern * #word)); pb = lowercase pattern bytes.
local function fuzzy_score(pb, m, w, lw, meta, plower, pexact)
	local lb, bon = meta.lb, meta.bon
	local n = #lb
	if n < m then return nil end

	local prev, cur = row_a, row_b
	local p1 = pb[1]
	for j = 1, n do
		if lb[j] == p1 then
			local lead = (j == 1) and 0 or (GAP_START + GAP_EXT * (j - 2))
			prev[j] = MATCH + bon[j] * 2 + lead
		else
			prev[j] = NEG
		end
	end

	for i = 2, m do
		local run = NEG
		local any = false
		local pi = pb[i]
		for j = 1, n do
			if j >= 3 then
				local a = run + GAP_EXT
				local b = prev[j - 2] + GAP_START
				run = (a > b) and a or b
			end
			cur[j] = NEG
			if lb[j] == pi then
				local best = NEG
				local bj = bon[j]
				if j >= 2 and prev[j - 1] > VALID then
					best = prev[j - 1] + (bj > B_CONSEC and bj or B_CONSEC)
				end
				if run > VALID and run + bj > best then
					best = run + bj
				end
				if best > VALID then
					cur[j] = best + MATCH
					any = true
				end
			end
		end
		if not any then return nil end
		prev, cur = cur, prev
	end

	local best = NEG
	for j = 1, n do
		if prev[j] > best then best = prev[j] end
	end
	if best <= VALID then return nil end

	if lw:sub(1, m) == plower then
		best = best + PREFIX_BONUS
		if w:sub(1, m) == pexact then best = best + PREFIX_CASE_BONUS end
	end
	return best
end

local function better(sa, wa, sb, wb)
	if sa ~= sb then return sa > sb end
	if #wa ~= #wb then return #wa < #wb end
	return wa < wb
end

-- Rank the words of `ix` against `prefix`. `pool` (optional) is a list of words
-- known to be a superset of the matches (result of an earlier, shorter prefix).
-- Returns: top items ({word=, score=}), new pool.
local function rank(ix, prefix, pool)
	local plower = prefix:lower()
	local m = #prefix
	local pb, pchars = {}, {}
	for i = 1, m do
		pb[i] = plower:byte(i)
		pchars[i] = plower:sub(i, i)
	end

	local src = pool or ix.list
	local newpool, np = {}, 0
	local top, nt = {}, 0
	local limit = M.max_items

	for k = 1, #src do
		local w = src[k]
		if w ~= prefix then
			local lw = ix.lower[w]
			if #lw >= m and is_subsequence(pchars, m, lw) then
				local s = fuzzy_score(pb, m, w, lw, word_meta(ix, w, lw), plower, prefix)
				if s then
					np = np + 1
					newpool[np] = w
					s = s + math.min(ix.count[w] or 1, 10)   -- frequency nudge
					if nt < limit or better(s, w, top[nt].score, top[nt].word) then
						-- insertion into the sorted top list
						local pos = (nt < limit) and (nt + 1) or nt
						while pos > 1 and better(s, w, top[pos - 1].score, top[pos - 1].word) do
							top[pos] = top[pos - 1]
							pos = pos - 1
						end
						top[pos] = { word = w, score = s }
						if nt < limit then nt = nt + 1 end
					end
				end
			end
		end
	end
	return top, newpool
end

------------------------------------------------------------------------------
-- Completion state
------------------------------------------------------------------------------

local S = {
	idx = 0,          -- 0 = typed text, 1..n = candidate currently inserted
	items = {},
	start = 0,        -- 0-based position where the word being completed starts
	orig = "",        -- what the user typed
	inserted = "",    -- what is in the buffer at `start` right now
	file = nil,
	ix = nil, ixv = nil, prefix = nil, pl = nil, pool = nil,
	dismissed = nil,  -- { start =, text = } : popup hidden until the prefix changes
	cand = nil,       -- word being typed, committed to the index once the cursor leaves it
}

local function reset_cycle()
	S.idx, S.items, S.inserted, S.orig = 0, {}, "", ""
	S.prefix, S.pl, S.pool, S.ix, S.ixv = nil, nil, nil, nil, nil
end

local function commit_cand()
	local c = S.cand
	if c then
		local ix = indexes[c.file]
		if ix then index_add(ix, c.word) end
		S.cand = nil
	end
end

-- Track the word under construction; when the cursor moves on, it becomes a candidate.
local function note_word(file, prefix, start)
	local c = S.cand
	if c then
		local same = prefix and c.file == file and c.start == start
			and (prefix:sub(1, #c.word) == c.word or c.word:sub(1, #prefix) == prefix)
		if not same then commit_cand() end
	end
	if prefix and usable_word(prefix) then
		S.cand = { file = file, start = start, word = prefix }
	end
end

-- The word characters directly before the cursor.
local function current_prefix(file, pos)
	if not pos or pos == 0 then return nil end
	local n = math.min(pos, 256)
	local before = file:content(pos - n, n)
	if not before then return nil end
	local prefix = before:match(WORD_END)
	if not prefix or prefix == "" or #prefix >= 256 then return nil end
	if prefix:find("^%d") then return nil end      -- a number, not an identifier
	return prefix, pos - #prefix
end

-- Bring the state in line with the buffer. Returns true while there is a list to show.
local function refresh(win)
	if win ~= vis.win then return false end

	if not M.enabled or vis.mode ~= vis.modes.INSERT or #win.selections ~= 1 then
		commit_cand()
		reset_cycle()
		-- edits made outside insert mode (dd, p, u, :s ...) are invisible to us,
		-- so the next insert session starts from a fresh scan
		indexes[win.file] = nil
		return false
	end

	local file = win.file
	local pos = win.selection.pos
	if not pos then reset_cycle(); return false end

	-- Mid-cycle: keep the list as long as the buffer is exactly as we left it.
	if S.idx > 0 then
		if S.file == file and pos == S.start + #S.inserted
		   and file:content(S.start, #S.inserted) == S.inserted then
			return true
		end
		reset_cycle()      -- the user typed / moved: candidate stays, popup closes
	end

	local prefix, start = current_prefix(file, pos)
	note_word(file, prefix, start)

	if not prefix or #prefix < M.min_chars then
		S.items, S.prefix, S.pool = {}, nil, nil
		return false
	end

	local d = S.dismissed
	if d then
		if d.start == start and d.text == prefix then
			S.items = {}
			return false
		end
		S.dismissed = nil
	end

	local ix = get_index(file, pos)
	if S.ix == ix and S.ixv == ix.version and S.prefix == prefix and S.start == start
	   and S.file == file then
		return #S.items > 0
	end

	local pl = prefix:lower()
	local pool
	if S.ix == ix and S.ixv == ix.version and S.pl and S.pool and pl:sub(1, #S.pl) == S.pl then
		pool = S.pool       -- the user only typed more: filter the previous matches
	end
	local items, newpool = rank(ix, prefix, pool)

	S.file, S.ix, S.ixv = file, ix, ix.version
	S.prefix, S.pl, S.pool = prefix, pl, newpool
	S.items, S.start = items, start
	S.orig, S.inserted, S.idx = prefix, prefix, 0
	return #items > 0
end

------------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------------

local function replace_inserted(win, text)
	local file = win.file
	file:delete(S.start, #S.inserted)
	file:insert(S.start, text)
	win.selection.pos = S.start + #text
	S.inserted = text
end

local function cycle(win, dir)
	if not refresh(win) or #S.items == 0 then return false end
	local n = #S.items
	local idx = (S.idx + dir) % (n + 1)
	replace_inserted(win, idx == 0 and S.orig or S.items[idx].word)
	S.idx = idx
	return true
end

local function cancel(win)
	if not refresh(win) or #S.items == 0 then return false end
	if S.idx > 0 then replace_inserted(win, S.orig) end
	S.dismissed = { start = S.start, text = S.orig }
	reset_cycle()
	return true
end

local function accept(win)
	if not refresh(win) or #S.items == 0 then return false end
	if S.idx == 0 then replace_inserted(win, S.items[1].word) end
	S.dismissed = { start = S.start, text = S.inserted }
	reset_cycle()
	return true
end

local actions = { next = function(w) return cycle(w, 1) end,
                  prev = function(w) return cycle(w, -1) end,
                  cancel = cancel, accept = accept }

------------------------------------------------------------------------------
-- "Popup": candidate list in the status bar
------------------------------------------------------------------------------

local function display_width(s)
	local _, n = s:gsub("[^\128-\191]", "")
	return n
end

local function render(win)
	local items, idx = S.items, S.idx
	local n = #items
	if n == 0 then return end

	local right = (idx > 0) and (idx .. "/" .. n .. " ")
		or (n .. (n == 1 and " match " or " matches "))
	local avail = win.width - display_width(right) - 2

	local labels, widths = {}, {}
	for i = 1, n do
		labels[i] = (i == idx) and ("[" .. items[i].word .. "]") or (" " .. items[i].word .. " ")
		widths[i] = display_width(labels[i])
	end

	-- scroll the visible window so the selected candidate stays on screen
	local first = 1
	if idx > 0 then
		local total = 0
		for i = first, idx do total = total + widths[i] end
		while total > avail and first < idx do
			total = total - widths[first]
			first = first + 1
		end
	end

	local parts, x, sel_x, sel_w = {}, 1, nil, 0
	for i = first, n do
		if x - 1 + widths[i] > avail and i > first then break end
		if i == idx then sel_x, sel_w = x, widths[i] end
		parts[#parts + 1] = labels[i]
		x = x + widths[i]
	end

	win:status(" " .. table.concat(parts), right)

	-- highlight the selected entry where the vis version supports it
	if sel_x and win.style_pos then
		local ids = vis.ui and vis.ui.style_ids
		if ids and ids.SELECTION then
			pcall(function()
				for c = sel_x, sel_x + sel_w - 1 do
					win:style_pos(ids.SELECTION, c, win.height - 1)
				end
			end)
		end
	end
end

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------

local installed = false
local installed_keys = {}

function M.setup(opts)
	if opts then
		for k, v in pairs(opts) do M[k] = v end
	end

	for _, key in ipairs(installed_keys) do
		pcall(function() vis:unmap(vis.modes.INSERT, key) end)
	end
	installed_keys = {}

	for _, m in ipairs(M.mappings) do
		local act = actions[m.action]
		if act then
			vis:map(vis.modes.INSERT, m.key, function()
				local win = vis.win
				if not (win and M.enabled and act(win)) and m.fallback then
					vis:feedkeys(m.fallback)
				end
			end, "Completion: " .. m.action)
			installed_keys[#installed_keys + 1] = m.key
		end
	end

	if installed then return M end
	installed = true

	vis.events.subscribe(vis.events.WIN_STATUS, function(win)
		if refresh(win) then render(win) end
	end)

	vis:command_register("complete", function(argv)
		local a = argv[1]
		if a == "on" then M.enabled = true
		elseif a == "off" then M.enabled = false
		else M.enabled = not M.enabled end
		if not M.enabled then reset_cycle() end
		vis:info("autocompletion " .. (M.enabled and "on" or "off"))
		return true
	end, "Toggle fuzzy autocompletion (on|off)")

	return M
end

-- exposed for testing
M._rank, M._scan, M._state = rank, scan, S
M._new_index, M._index_add = new_index, index_add

return M
