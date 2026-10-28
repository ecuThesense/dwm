#!/usr/bin/env bash

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

out=$(
  find /usr/bin /usr/local/bin ~/.local/bin \
    -maxdepth 1 \( -type f -o -type l \) -executable -print 2>/dev/null |
    sort -u |
    fzf \
      --color="bg+:${FZF_ACCENT:-#3584e4}" \
      --style=full \
      --expect=ctrl-s \
      --preview 'if [ "$(file -b --mime-encoding {})" = binary ]; then file -b {}; else cat {}; fi' \
      --bind 'focus:transform-header:file --brief {}'
)

key=$(sed -n 1p <<<"$out")
file=$(sed -n 2p <<<"$out")

[ -n "$file" ] || exit 0

if [ "$key" = ctrl-s ]; then
  "$file" # TUI: runs in this terminal (nvim, htop, ...)
  # exec "$SHELL" # uncomment to keep the terminal open as a shell afterwards
else
  setsid -f "$file" >/dev/null 2>&1 # GUI: detached, terminal can close
fi
