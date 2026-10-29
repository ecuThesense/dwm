#!/bin/sh
file=$(find . -type f 2>/dev/null | fzf)

[ -n "$file" ] && xdg-open "$file" >/dev/null 2>&1
