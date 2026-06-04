#!/usr/bin/env bash
# Quick categorized Hyprland cheat sheet via rofi.
# A curated, at-a-glance reference grouped by category.
# Themed with wallust via config-keybinds.rasi -> theme.rasi -> colors-rofi.rasi.

rofi_theme="$HOME/.config/rofi/config-keybinds.rasi"
msg='i3/sway-style Hyprland keybinds — SUPER is the mod key'

# Toggle: if rofi is already open, close it and exit.
if pidof rofi >/dev/null; then
  pkill rofi
  exit 0
fi

entries=(
  "──  Focus / Move  ──"
  "SUPER + h/j/k/l         Focus left/down/up/right"
  "SUPER + arrows          Focus (arrow keys)"
  "SUPER + ;               Easymotion jump to window"
  "SUPER + Shift + h/j/k/l Move window in direction"
  "SUPER + Shift + arrows  Move window (arrow keys)"

  "──  Layout  ──"
  "SUPER + E               Split opposite direction"
  "SUPER + V               Split vertical"
  "SUPER + B               Split horizontal"
  "SUPER + P               Toggle pseudotile"
  "SUPER + F               Fullscreen"
  "SUPER + Shift + F       Maximize (keep gaps/bar)"
  "SUPER + Shift + Space   Toggle floating"

  "──  Tabs / Nodes  ──"
  "SUPER + W               Toggle tab group"
  "SUPER + Tab             Next tab"
  "SUPER + Shift + Tab     Previous tab"
  "SUPER + Alt + h         Untab group"
  "SUPER + Alt + l         Flip split orientation"

  "──  Resize mode  ──"
  "SUPER + R               Enter resize mode"
  "  h/j/k/l or arrows     Resize active window"
  "  Esc / Return          Exit resize mode"

  "──  Workspaces  ──"
  "SUPER + 1..0            Switch to workspace 1-10"
  "SUPER + Shift + 1..0    Move window to workspace"
  "SUPER + Ctrl + h/l      Previous / next workspace"
  "SUPER + scroll          Cycle workspaces"
  "SUPER + minus           Toggle scratchpad"
  "SUPER + Shift + minus   Move window to scratchpad"

  "──  Monitors  ──"
  "SUPER + Shift + ,       Move window to left monitor"
  "SUPER + Shift + .       Move window to right monitor"

  "──  Apps / Session  ──"
  "SUPER + Return          Terminal (ghostty)"
  "SUPER + D               App launcher (rofi)"
  "SUPER + Shift + Return  File manager (thunar)"
  "SUPER + Shift + Q       Kill active window"
  "SUPER + Shift + C       Reload config"
  "SUPER + Shift + E       Exit / logout"
  "SUPER + Shift + X       Lock screen"

  "──  Screenshots  ──"
  "SUPER + Shift + 3       Full screen to file"
  "SUPER + Shift + 4       Region to file"
  "SUPER + Shift + 5       Region to clipboard"
  "SUPER + Shift + S       Region annotate (swappy)"

  "──  Mouse  ──"
  "SUPER + LMB drag        Move window"
  "SUPER + RMB drag        Resize window"

  "──  Cheat Sheet  ──"
  "SUPER + /               Search all keybinds"
  "SUPER + Shift + /       This quick cheat sheet"
)

printf '%s\n' "${entries[@]}" | rofi -dmenu -i -config "$rofi_theme" -mesg "$msg"
