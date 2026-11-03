#!/usr/bin/env bash
# notes-dmenu.sh - browse, search and edit notes in ~/notes with dmenu
#
# Browse view:  ".." (go up), folders (name/), notes, and "search all"
# Search view:  flat list of every note below the current folder (relative paths)
# Typing a name that doesn't exist and pressing Enter creates a new note
#   (".md" is appended if you give no extension; "sub/name" creates subfolders)
#
# Env overrides: NOTES_DIR, EDITOR

NOTES_DIR="${NOTES_DIR:-$HOME/notes}"
EDITOR_CMD="${EDITOR:-nvim}"
TERM_FONT='AdwaitaMono Nerd Font:size=16'
SEARCH_ENTRY="/ search all (here and below)"

mkdir -p "$NOTES_DIR"

menu() { dmenu -i -l 20 -p "$1"; }

open_note() {
  setsid -f st -f "$TERM_FONT" -e "$EDITOR_CMD" "$1" >/dev/null 2>&1
}

search_all() {
  local base="$1" rel sel
  rel="${base#"$NOTES_DIR"}"
  rel="${rel#/}"
  sel=$(find "$base" -type f ! -path '*/.*' -printf '%P\n' | sort | menu "search notes/${rel}") || return 1
  [ -n "$sel" ] && [ -f "$base/$sel" ] || return 1
  open_note "$base/$sel"
  return 0
}

cur="$NOTES_DIR"

while true; do
  rel="${cur#"$NOTES_DIR"}"
  rel="${rel#/}"

  entries=$(
    if [ "$cur" != "$NOTES_DIR" ]; then echo ".."; fi
    echo "$SEARCH_ENTRY"
    find "$cur" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f/\n' | sort
    find "$cur" -mindepth 1 -maxdepth 1 -type f ! -name '.*' -printf '%f\n' | sort
  )

  choice=$(printf '%s\n' "$entries" | menu "notes/${rel}") || exit 0
  [ -z "$choice" ] && exit 0

  case "$choice" in
  "..")
    [ "$cur" != "$NOTES_DIR" ] && cur=$(dirname "$cur")
    ;;
  "$SEARCH_ENTRY")
    search_all "$cur" && exit 0
    ;;
  */)
    if [ -d "$cur/${choice%/}" ]; then
      cur="$cur/${choice%/}"
    fi
    ;;
  *)
    # refuse anything that tries to escape the notes dir
    case "$choice" in *..*) continue ;; esac

    target="$cur/$choice"
    if [ ! -e "$target" ]; then
      # new note: add .md if no extension was typed
      case "$(basename "$choice")" in
      *.*) ;;
      *) target="$target.md" ;;
      esac
      mkdir -p "$(dirname "$target")"
    fi
    open_note "$target"
    exit 0
    ;;
  esac
done
