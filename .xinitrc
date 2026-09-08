~/dwm/dwm/scripts/statusbar.sh &
statusbar_pid=$!
xwallpaper --zoom ~/Pictures/wallhaven.png &
trap "kill $statusbar_pid" EXIT

dwm
kill $statusbar_pid 2>/dev/null
