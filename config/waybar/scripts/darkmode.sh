#!/usr/bin/env bash
# Waybar dark-mode indicator/toggle backed by darkman.
#
# `darkman watch` prints the current mode immediately at startup, then one line
# per mode change (natural sunrise/sunset transitions AND manual `darkman toggle`),
# so this module stays in sync event-driven with no polling.
#
# A manual toggle (on-click in waybar config) only lasts until darkman's next
# scheduled transition, so it never interferes with the natural cycle.

emit() {
    case "$1" in
        dark)
            printf '{"text": "󰖔", "alt": "dark", "class": "dark", "tooltip": "Dark mode — reverts at sunrise (click for light)"}\n'
            ;;
        light)
            printf '{"text": "󰖨", "alt": "light", "class": "light", "tooltip": "Light mode — reverts at sunset (click for dark)"}\n'
            ;;
    esac
}

# If the darkman daemon isn't up yet (login race), watch exits non-zero;
# waybar's restart-interval re-launches us until it succeeds.
darkman watch 2>/dev/null | while read -r mode; do
    emit "$mode"
done
