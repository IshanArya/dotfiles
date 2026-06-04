#!/usr/bin/env bash
# Searchable Hyprland keybinds via rofi.
# Auto-generated from ~/.config/hypr/keybinds.conf using keybinds_parser.py.
# Themed with wallust via config-keybinds.rasi -> theme.rasi -> colors-rofi.rasi.

keybinds_conf="$HOME/.config/hypr/keybinds.conf"
parser="$HOME/.config/hypr/scripts/keybinds_parser.py"
rofi_theme="$HOME/.config/rofi/config-keybinds.rasi"
msg='NOTE: Pressing ENTER or clicking does nothing — this is a reference list'

# Toggle: if rofi is already open, close it and exit.
if pidof rofi >/dev/null; then
  pkill rofi
  exit 0
fi

display_keybinds=$("$parser" "$keybinds_conf")

printf '%s\n' "$display_keybinds" | rofi -dmenu -i -config "$rofi_theme" -mesg "$msg"
