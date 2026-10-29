#!/bin/sh
# bm="$HOME/bookmarks.html"
# ddg_url="https://www.duckduckgo.com"
#
# # Launched from a graphical menu: run the picker in GNOME Terminal,
# # wait for it to close, then open Firefox from here.
# if [ ! -t 0 ] || [ ! -t 1 ]; then
#     case "$0" in
#         /*) script_path="$0" ;;
#         *)  script_path="$PWD/$0" ;;
#     esac
#
#     out=$(mktemp)
#     gnome-terminal --wait -- "$script_path" "$out"
#     url=$(cat "$out")
#     rm -f "$out"
#
#     [ -n "$url" ] && exec firefox --new-tab "$url"
#     exit 0
# fi
#
# # Parse Firefox bookmarks: URL<TAB>title.
# pairs=""
# if [ -s "$bm" ]; then
#     pairs=$(
#         sed -n \
#             's/.*<A HREF="\([^"]*\)"[^>]*>\(.*\)<\/A>.*/\1\t\2/p' \
#             "$bm" |
#         sed 's/\&lt;/</g; s/\&gt;/>/g; s/\&quot;/"/g; s/\&amp;/\&/g'
#     )
# fi
#
# # Build the displayed bookmark list.
# menu=$(
#     printf '%s\n' "$pairs" |
#         awk -F '\t' 'NF >= 2 { print $2 " | " $1 }' |
#         sort -f
# )
#
# # Select a bookmark, or enter a URL.
# sel=$(
#     {
#         [ -n "$menu" ] && printf '%s\n' "$menu"
#     } |
#     fzf \
#         --prompt='Bookmark / URL: ' \
#         --header='Select a bookmark or type a URL' \
#         --bind='enter:accept-or-print-query'
# )
#
# [ -z "$sel" ] && exit 0
#
# # If the selected line belongs to a bookmark, extract its URL.
# url=$(
#     printf '%s\n' "$pairs" |
#         T="$sel" awk -F '\t' \
#             'NF >= 2 && ($2 " | " $1) == ENVIRON["T"] {
#                 print $1
#                 exit
#             }'
# )
#
# # Otherwise interpret the typed input.
# if [ -z "$url" ]; then
#     case "$sel" in
#         http://*|https://*|file://*|about:*)
#             url=$sel
#             ;;
#         *[[:space:]]*)
#             url=$ddg_url
#             ;;
#         *.*)
#             url="https://$sel"
#             ;;
#         *)
#             url=$ddg_url
#             ;;
#     esac
# fi
#
# # Hand the URL back to the launcher; if run by hand, open it directly.
# if [ -n "$1" ]; then
#     printf '%s' "$url" > "$1"
# else
#     firefox --new-tab "$url" >/dev/null 2>&1 &
# fi

bm="$HOME/bookmarks.html"

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

search_url() {
  q=$(printf '%s' "$1" |
    od -An -v -tx1 |
    tr -d ' \n' |
    sed 's/../%&/g')

  printf 'https://duckduckgo.com/?q=%s' "$q"
}

# Launched from a graphical menu: run the picker in GNOME Terminal,
# wait for it to close, then open Firefox from here.
if [ ! -t 0 ] || [ ! -t 1 ]; then
  case "$0" in
  /*) script_path="$0" ;;
  *) script_path="$PWD/$0" ;;
  esac

  out=$(mktemp)
  st -f "AdwaitaMono Nerd Font:size=16" -e "$script_path" "$out"
  mode=$(sed -n 1p "$out")
  url=$(sed -n 2p "$out")
  rm -f "$out"

  [ -z "$url" ] && exit 0
  if [ "$mode" = tab ]; then
    exec firefox --new-tab "$url"
  else
    exec firefox --new-window "$url"
  fi
fi

# Parse Firefox bookmarks: URL<TAB>title.
pairs=""
if [ -s "$bm" ]; then
  pairs=$(
    sed -n \
      's/.*<A HREF="\([^"]*\)"[^>]*>\(.*\)<\/A>.*/\1\t\2/p' \
      "$bm" |
      sed 's/\&lt;/</g; s/\&gt;/>/g; s/\&quot;/"/g; s/\&amp;/\&/g'
  )
fi

# Build the displayed bookmark list.
menu=$(
  printf '%s\n' "$pairs" |
    awk -F '\t' 'NF >= 2 { print $2 " | " $1 }' |
    sort -f
)

# Enter = open highlighted bookmark, Ctrl-S = use exactly what I typed.
# Output lines: 1) typed query  2) key pressed (empty for Enter)  3) selection
res=$(
  {
    [ -n "$menu" ] && printf '%s\n' "$menu"
  } |
    fzf \
      --color="bg+:${FZF_ACCENT:-#3584e4}" \
      --prompt='Bookmark / URL / Search: ' \
      --header='Enter: open bookmark | Ctrl-S: search or open typed text' \
      --print-query \
      --expect=ctrl-s
)

[ -z "$res" ] && exit 0

query=$(printf '%s\n' "$res" | sed -n 1p)
key=$(printf '%s\n' "$res" | sed -n 2p)
sel=$(printf '%s\n' "$res" | sed -n 3p)

if [ "$key" = ctrl-s ] || [ -z "$sel" ]; then
  # Typed text: open it as a URL, or search for it.
  mode=window
  case "$query" in
  '')
    exit 0
    ;;
  http://* | https://* | file://* | about:*)
    url=$query
    ;;
  *[[:space:]]*)
    url=$(search_url "$query")
    ;;
  *.*)
    url="https://$query"
    ;;
  *)
    url=$(search_url "$query")
    ;;
  esac
else
  # Highlighted bookmark: look up its URL.
  mode=tab
  url=$(
    printf '%s\n' "$pairs" |
      T="$sel" awk -F '\t' \
        'NF >= 2 && ($2 " | " $1) == ENVIRON["T"] {
                    print $1
                    exit
                }'
  )
fi

[ -z "$url" ] && exit 0

# Hand the URL back to the launcher; if run by hand, open it directly.
if [ -n "$1" ]; then
  printf '%s\n%s' "$mode" "$url" >"$1"
else
  if [ "$mode" = tab ]; then
    firefox --new-tab "$url" >/dev/null 2>&1 &
  else
    firefox --new-tab "$url" >/dev/null 2>&1 &
  fi
fi
