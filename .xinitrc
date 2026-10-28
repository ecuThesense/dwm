export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=dwm
export XDG_SESSION_DESKTOP=dwm

setxkbmap -layout de,ru -option 'grp:alt_shift_toggle'

dbus-update-activation-environment --systemd \
    DISPLAY \
    XAUTHORITY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_DESKTOP \
    XDG_SESSION_TYPE \
    XDG_DATA_DIRS

xwallpaper --zoom ~/SourceApps/dwm/Wallpapers/wallhaven.png &

slstatus &
lxpolkit &
exec dbus-run-session dwm
