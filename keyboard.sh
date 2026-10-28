setxkbmap -layout de,ru -option 'grp:alt_shift_toggle'

# /etc/X11/xorg.conf.d/00-keyboard.conf
#
# Section "InputClass"
#     Identifier "Keyboard Defaults"
#     MatchIsKeyboard "on"
#
#     Option "XkbLayout" "de,ru"
#     Option "XkbOptions" "grp:alt_shift_toggle"
# EndSection
