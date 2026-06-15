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
  "Print                   Region to file"
  "SUPER + Print           Full screen to file"
  "SUPER + Shift + Print   Region annotate (swappy)"
  "SUPER + Shift + S       Region to clipboard"

  "──  Mouse  ──"
  "SUPER + LMB drag        Move window"
  "SUPER + RMB drag        Resize window"

  "──  Cheat Sheet  ──"
  "SUPER + /               Search all keybinds"
  "SUPER + Shift + /       This quick cheat sheet"
)

# Emit NUL-delimited rofi dmenu rows. Each entry carries an invisible "meta"
# keyword (its section name) so typing a category (e.g. "Screenshots") surfaces
# every binding in that section. Section headers themselves are marked
# nonselectable so they can't be activated. Display stays visually identical.
emit_rows() {
  local section=""
  local entry
  for entry in "${entries[@]}"; do
    if [[ "$entry" =~ ^──[[:space:]]*(.*[^[:space:]])[[:space:]]*──$ ]]; then
      # Section header: capture name for following rows, make it nonselectable.
      section="${BASH_REMATCH[1]}"
      printf '%s\x00nonselectable\x1ftrue\x1fmeta\x1f%s\n' "$entry" "$section"
    elif [[ -n "$entry" ]]; then
      printf '%s\x00meta\x1f%s\n' "$entry" "$section"
    else
      printf '\n'
    fi
  done
}

emit_rows | rofi -dmenu -i -config "$rofi_theme" -mesg "$msg"
