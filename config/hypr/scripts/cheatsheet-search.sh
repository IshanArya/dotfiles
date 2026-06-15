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

# Pipe parser output straight into rofi: rows are NUL-delimited and may carry
# an invisible "meta" keyword (the section name) so searching a category name
# (e.g. "Screenshot") surfaces every binding in that section. Capturing in a
# variable would strip the NUL bytes, so we pipe directly.
"$parser" "$keybinds_conf" | rofi -dmenu -i -config "$rofi_theme" -mesg "$msg"
