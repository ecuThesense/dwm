require("vis")
require("complete").setup()
-- ==========================================
-- Native mode indicator and status line
-- No third-party plugins or themes required
-- ==========================================

local ui = vis.ui

-- Mode names
local mode_names = {
	[vis.modes.NORMAL] = " NORMAL ",
	[vis.modes.INSERT] = " INSERT ",
	[vis.modes.VISUAL] = " VISUAL ",
	[vis.modes.VISUAL_LINE] = " V-LINE ",
	[vis.modes.REPLACE] = " REPLACE ",
	[vis.modes.OPERATOR_PENDING] = " OPERATOR ",
}

-- High-contrast mode colors
local mode_colors = {
	[vis.modes.NORMAL] = "fore:#1e1e2e,back:#89b4fa,bold",

	[vis.modes.INSERT] = "fore:#1e1e2e,back:#a6e3a1,bold",

	[vis.modes.VISUAL] = "fore:#1e1e2e,back:#cba6f7,bold",

	[vis.modes.VISUAL_LINE] = "fore:#1e1e2e,back:#f5c2e7,bold",

	[vis.modes.REPLACE] = "fore:#1e1e2e,back:#f38ba8,bold",

	[vis.modes.OPERATOR_PENDING] = "fore:#1e1e2e,back:#fab387,bold",
}

local inactive_style = "fore:#bac2de,back:#181825"

-- Apply our status colors after Vis initializes its theme.
vis.events.subscribe(vis.events.INIT, function()
	ui:style_define(ui.style_ids.STATUS, inactive_style)

	ui:style_define(ui.style_ids.STATUS_FOCUSED, mode_colors[vis.modes.NORMAL])
end)

-- Draw our own status line.
-- Priority 1 places this before Vis's standard handler.
vis.events.subscribe(vis.events.WIN_STATUS, function(win)
	local active = vis.win == win
	local mode = active and vis.mode or vis.modes.NORMAL

	if active then
		ui:style_define(ui.style_ids.STATUS_FOCUSED, mode_colors[mode] or mode_colors[vis.modes.NORMAL])
	end

	local file = win.file
	local selection = win.selection

	local filename = file.name or "[No Name]"

	if file.modified then
		filename = filename .. " [+]"
	end

	if active and vis.recording then
		filename = filename .. " @REC"
	end

	local label = active and (mode_names[mode] or " NORMAL ") or ""

	local left = " " .. label .. filename .. " "

	local size = file.size or 0
	local pos = selection.pos or 0
	local percent = size > 0 and math.floor(pos / size * 100) or 0

	local right_parts = {}

	if active and vis.input_queue ~= "" then
		table.insert(right_parts, vis.input_queue)
	elseif active and vis.count then
		table.insert(right_parts, tostring(vis.count))
	end

	if #win.selections > 1 then
		table.insert(right_parts, selection.number .. "/" .. #win.selections)
	end

	table.insert(right_parts, percent .. "%")
	table.insert(right_parts, selection.line .. ":" .. selection.col)

	local right = " " .. table.concat(right_parts, " | ") .. " "

	win:status(left, right)

	-- Stop the default status handler from replacing ours.
	return true
end, 1)

-- config --

-- global
vis.events.subscribe(vis.events.INIT, function()
	vis:command("set theme tokyonight-moon")
end)
-- per-window
vis.events.subscribe(vis.events.WIN_OPEN, function(win)
	vis:command("set numbers")
	vis:command("set relativenumbers")
	vis:command("set cursorline")
	vis:command("set autoindent")
	vis:command("set showspaces")
	vis:command("set showtabs")
	vis:command("set expandtab")
	vis:command("set tabwidth 4")
	vis:command("set shell /bin/sh")
	vis:map(vis.modes.VISUAL, " y", '"+y"')
	vis:map(vis.modes.NORMAL, " fm", function()
		vis:command("open .")
	end, "")
end)

-- plugins --

-- modal
-- local modal = require("plugins/vis-modal")
-- vis-autoclose
local autoclose = require("plugins/vis-autoclose")
-- colorizer
-- local colorizer = require("plugins/vis-colorizer")
-- colorizer.three = false
-- colorizer.six = true
-- complete-filename
local completefilename = require("plugins/complete-filename")
-- vis-lspc
--local lsp = require("plugins/vis-lspc")
--lsp.ls_map.clangd = {
--	formatting_options = {tabSize = 2, insertSpaces = false}
--}
--lsp.ls_map.lua = {
--	name = "lua-language-server",
--	cmd = "lua-language-server",
--	settings = {
--		Lua = { diagnostics = { globals = { "vis" } }, telemetry = { enable = false } },
--	},
--	formatting_options = { tabSize = 2, insertSpaces = true },
--}
