#!/usr/bin/env bash
#
# run - fzf command launcher with live completion
#
#   Type any command (doas/sudo in front is fine). Suggestions for command names,
#   subcommands, flags, package names, hostnames, file paths ... update as you type.
#
#     Tab         put the highlighted suggestion into the input line
#     Enter       run exactly what is in the input line (in this terminal)
#     Alt-Enter   run it detached (for GUI programs; not for TUI programs or doas)
#     Esc         quit
#
#   A single path (contains a / or starts with ~) is opened with xdg-open when it
#   is a directory or a file that is not executable.
#
#   Install:  cp run.sh ~/.local/bin/run && chmod +x ~/.local/bin/run
#   Launch:   run                                    (from a shell)
#             foot -e /home/YOU/.local/bin/run --hold  (from a keybinding; --hold keeps
#                                                      the window open until you press Enter)
#
#   Needs: bash, fzf (0.35+). Recommended: bash-completion, man-db.
#   Flag cache: ~/.cache/fzf-run   (delete the folder to refresh it)

# ----------------------------------------------------------------------
# helpers used by the suggestion generator
# ----------------------------------------------------------------------

# Read the current GNOME accent color independently of Bash
accent_name=$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null |
  tr -d "'")

case "$accent_name" in
teal) FZF_ACCENT='#2190a4' ;;
green) FZF_ACCENT='#3a944a' ;;
yellow) FZF_ACCENT='#c88800' ;;
orange) FZF_ACCENT='#ed5b00' ;;
red) FZF_ACCENT='#e62d42' ;;
pink) FZF_ACCENT='#d56199' ;;
purple) FZF_ACCENT='#9141ac' ;;
slate) FZF_ACCENT='#6f8396' ;;
*) FZF_ACCENT='#3584e4' ;;
esac

export FZF_ACCENT

# file-name candidates for a typed word; a leading ~ is kept as typed
file_candidates() {
  local typed="$1" real="${1/#\~/$HOME}" f
  compgen -f -- "$real" | sort | while IFS= read -r f; do
    [[ "$typed" == "~"* ]] && f="~${f#"$HOME"}"
    printf '%s\n' "$f"
  done
}

# reads candidates on stdin, prints complete command lines (prefix + candidate + suffix)
#   RUN_ESC=1    always shell-escape the candidate (used for file names)
#   RUN_NODIR=1  do not append / to candidates that match a directory
emit() {
  local item suffix n=0
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    suffix=" "
    if [ -z "$RUN_NODIR" ] && [ -d "${item/#\~/$HOME}" ]; then
      [[ $item == */ ]] && suffix="" || suffix="/"
    elif [[ $item == *[/=] ]]; then
      suffix=""
    fi
    if [ -n "$RUN_ESC" ] || [[ $item == *[[:space:]]* && $item != *\\* ]]; then
      printf -v item '%q' "$item"
      [[ $item == \\~* ]] && item=${item:1}
    fi
    printf '%s\n' "$RUN_BASE$item$suffix"
    ((++n >= 300)) && break
  done
}

# flags of a command, taken from its man page (no execution). Only if there is no
# man page, a real binary from a system directory is asked once for --help.
gather_flags() {
  local cmd="$1" out bin
  local pat='(^|[[:space:],|\[(])-{1,2}[[:alpha:]][-[:alnum:]_]*'
  out=$(LC_ALL=C MANWIDTH=200 MANPAGER=cat man "$cmd" 2>/dev/null | sed 's/.\x08//g')
  if [ -z "$out" ]; then
    bin=$(command -v "$cmd") || bin=""
    if [[ "$bin" == /usr/* || "$bin" == /bin/* || "$bin" == /sbin/* || "$bin" == /opt/* ]] &&
      [ "$(head -c4 "$bin" 2>/dev/null | tr -d '\0')" = $'\x7fELF' ]; then
      out=$(timeout 2 "$cmd" --help </dev/null 2>&1)
    fi
  fi
  grep -oE -- "$pat" <<<"$out" | sed 's/^[^-]*//' | sort -u
}

# same, but cached on disk so typing does not re-read man pages on every keystroke
flags_for() {
  local cmd="$1" dir f tmp
  command -v "$cmd" >/dev/null 2>&1 || return 0
  dir="${XDG_CACHE_HOME:-$HOME/.cache}/fzf-run"
  f="$dir/${cmd//\//_}.flags"
  if [ ! -f "$f" ]; then
    mkdir -p "$dir"
    tmp=$(mktemp "$dir/.tmp.XXXXXX") || return 0
    gather_flags "$cmd" >"$tmp"
    mv -f "$tmp" "$f"
  fi
  cat "$f"
}

# ----------------------------------------------------------------------
# part 1: suggestion generator - fzf calls this on every keystroke
#   usage: run --suggest "<text typed so far>"
#   debug: bash run.sh --suggest 'doas apt ins'
# ----------------------------------------------------------------------
if [ "$1" = "--suggest" ]; then
  line="$2"
  line="${line#"${line%%[![:space:]]*}"}" # trim leading whitespace
  [ -z "$line" ] && exit 0

  # keep doas/sudo in front and complete the command behind it
  pre=""
  while [[ "$line" =~ ^(doas|sudo)[[:space:]]+(.*)$ ]]; do
    pre+="${BASH_REMATCH[1]} "
    line="${BASH_REMATCH[2]}"
  done

  # split into words; a trailing space means "start a new, empty word"
  read -ra words <<<"$line"
  [[ "$line" == *[[:space:]] ]] && words+=("")
  [ "${#words[@]}" -eq 0 ] && words=("")
  cword=$((${#words[@]} - 1))
  cur="${words[cword]}"
  RUN_BASE="$pre${line%"$cur"}"

  # --- first word: command names (prefix matches first, then fuzzy matches) ---
  if [ "$cword" -eq 0 ]; then
    if [[ "$cur" == */* || "$cur" == "~"* || "$cur" == .* ]]; then
      file_candidates "$cur" | RUN_ESC=1 emit
    else
      {
        compgen -c -- "$cur" | sort -u
        compgen -c | sort -u | fzf --filter="$cur" 2>/dev/null
      } | awk '!seen[$0]++' | RUN_NODIR=1 emit
    fi
    exit 0
  fi

  cmd="${words[0]}"

  # --- installed bash-completion definitions: flags, subcommands, packages, hosts ... ---
  if [ -r /usr/share/bash-completion/bash_completion ]; then
    source /usr/share/bash-completion/bash_completion >/dev/null 2>&1
    spec=$(complete -p "$cmd" 2>/dev/null)
    if [ -z "$spec" ]; then
      { _comp_load "$cmd" || _completion_loader "$cmd"; } >/dev/null 2>&1
      spec=$(complete -p "$cmd" 2>/dev/null)
    fi
    func=""
    [[ "$spec" =~ -F[[:space:]]+([^[:space:]]+) ]] && func="${BASH_REMATCH[1]}"

    if [ -n "$func" ] && [ "$func" != _minimal ] && declare -F "$func" >/dev/null; then
      COMP_WORDS=("${words[@]}")
      COMP_CWORD=$cword
      COMP_LINE="$line"
      COMP_POINT=${#line}
      COMP_TYPE=9
      COMP_KEY=9
      COMPREPLY=()
      "$func" "$cmd" "$cur" "${words[cword - 1]}" >/dev/null 2>&1
      if [ "${#COMPREPLY[@]}" -gt 0 ]; then
        printf '%s\n' "${COMPREPLY[@]}" | sort -u | emit
        exit 0
      fi
    fi
  fi

  # --- no definition (or nothing found): flags from man page / --help, else file paths ---
  if [[ "$cur" == -* ]]; then
    flags_for "$cmd" | C="$cur" awk 'index($0, ENVIRON["C"]) == 1' | emit
    exit 0
  fi
  file_candidates "$cur" | RUN_ESC=1 emit
  exit 0
fi

# ----------------------------------------------------------------------
# part 2: interactive launcher
# ----------------------------------------------------------------------
hold=0
[ "$1" = "--hold" ] && hold=1

command -v fzf >/dev/null 2>&1 || {
  echo "run: fzf not found" >&2
  exit 1
}

self=$(realpath "$0")

# stdin is /dev/null so fzf does not start its default file search;
# SHELL=/bin/bash makes sure fzf quotes {q} for bash, whatever your login shell is
out=$(
  SHELL=/bin/bash fzf \
    --color="bg+:${FZF_ACCENT:-#3584e4}" \
    --disabled --print-query --expect=alt-enter --no-sort \
    --layout=reverse --prompt='$ ' \
    --header='Tab: take suggestion | Enter: run | Alt-Enter: run detached | Esc: quit' \
    --bind "start:reload:bash '$self' --suggest {q}" \
    --bind "change:reload:bash '$self' --suggest {q}" \
    --bind 'tab:replace-query' \
    </dev/null
)
rc=$?
[ "$rc" -eq 130 ] && exit 0   # Esc / Ctrl-C
[ "$rc" -gt 1 ] && exit "$rc" # fzf error

mapfile -t lines <<<"$out"
query="${lines[0]}"
key="${lines[1]}"
query="${query#"${query%%[![:space:]]*}"}" # trim
query="${query%"${query##*[![:space:]]}"}"
[ -n "$query" ] || exit 0

# a lone path: open directories and non-executable files with xdg-open
if [[ "$query" != *[[:space:]]* && ("$query" == */* || "$query" == "~"*) ]]; then
  target="${query/#\~/$HOME}"
  if [ -d "$target" ] || { [ -f "$target" ] && [ ! -x "$target" ]; }; then
    setsid -f xdg-open "$target" </dev/null >/dev/null 2>&1
    exit 0
  fi
fi

# Alt-Enter: detached, for GUI programs
if [ "$key" = alt-enter ]; then
  setsid -f bash -c "$query" </dev/null >/dev/null 2>&1
  exit 0
fi

# --hold: keep the terminal open after the command finished
if [ "$hold" = 1 ]; then
  bash -c "$query"
  rc=$?
  printf '\n[exit %s] press Enter to close ' "$rc"
  read -r _
  exit "$rc"
fi

exec bash -c "$query"
