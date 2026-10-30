#!/bin/sh
# dmenu exit menu for dwm

choice=$(printf '%s\n' \
  '  Lock' \
  '󰈆  Exit' \
  '󰒲  Suspend' \
  '󰤄  Hibernate' \
  '  Reboot' \
  '  Shutdown' |
  dmenu -i -fn "AdwaitaMono Nerd Font:size=14" -p "Exit:") || exit 0

case "$choice" in
*Lock) slock ;;
*Exit) pkill -x dwm ;;
*Suspend) systemctl suspend ;;
*Hibernate) systemctl hibernate ;;
*Reboot) systemctl reboot ;;
*Shutdown) systemctl poweroff ;;
esac
