#!/bin/sh
while true; do
    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | sed 's/Volume: //')
    bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    date=$(date '+%a %d %b %H:%M')

    xsetroot -name "VOL:${vol} | BAT:${bat}% | ${date}"
    sleep 5
done
