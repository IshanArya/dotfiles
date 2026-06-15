#!/usr/bin/env bash
# ==================================================
#  theme-switch.sh
#  Switch wallpaper + wallust palette + GTK3 dark/light on darkman mode change.
#  Usage: theme-switch.sh <dark|light>
#  Triggered by darkman hooks (~/.local/share/{dark,light}-mode.d/theme).
# ==================================================
set -uo pipefail

MODE="${1:-}"
case "$MODE" in
  dark)  SET_DIR="Dark";  GTK_DARK=1 ;;
  light) SET_DIR="Light"; GTK_DARK=0 ;;
  *) echo "usage: $0 <dark|light>" >&2; exit 1 ;;
esac

WALL_BASE="$HOME/Photos/Wallpapers"
WALL_DIR="$WALL_BASE/$SET_DIR"

# Monitors are hardcoded (no jq dependency). Adjust if your outputs change.
MONITORS="DP-1,DP-2"

# awww transition (Hyprland-Dots style growing circle).
TRANSITION=(--transition-type any --transition-duration 2 --transition-fps 60 --transition-bezier .43,1.19,1,.4)

# ---- Resolve wallpaper -------------------------------------------------------
# Currently picks the single image in the mode dir. For per-workspace sets later
# this becomes "$WALL_DIR/<workspace>.jpg" (see scripts/README-wallpaper-per-workspace.md).
WALL="$(find -L "$WALL_DIR" -maxdepth 1 -type f \
  \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
  | sort | head -n1)"

if [[ -z "$WALL" || ! -f "$WALL" ]]; then
  command -v notify-send >/dev/null && \
    notify-send -u critical "theme-switch" "No wallpaper found in $WALL_DIR"
  echo "no wallpaper in $WALL_DIR" >&2
  exit 1
fi

# ---- Wallpaper ---------------------------------------------------------------
if ! pgrep -x awww-daemon >/dev/null; then
  awww-daemon &
  for _ in {1..20}; do awww query >/dev/null 2>&1 && break; sleep 0.1; done
fi
awww img -o "$MONITORS" "$WALL" "${TRANSITION[@]}" || \
  awww img "$WALL" "${TRANSITION[@]}" || true

# ---- Wallust palette ---------------------------------------------------------
# Regenerates all templates defined in ~/.config/wallust/wallust.toml.
command -v wallust >/dev/null && wallust run -s "$WALL" || true

# ---- GTK3 (Thunar et al.) dark/light toggle ----------------------------------
# GTK3 apps don't follow the XDG portal hint; they need this in settings.ini.
# Brave/GTK4 are handled separately by darkman's portal:true (untouched).
GTK3_INI="$HOME/.config/gtk-3.0/settings.ini"
mkdir -p "$(dirname "$GTK3_INI")"
[[ -f "$GTK3_INI" ]] || printf '[Settings]\n' > "$GTK3_INI"
if grep -q '^\[Settings\]' "$GTK3_INI"; then
  if grep -q '^gtk-application-prefer-dark-theme' "$GTK3_INI"; then
    sed -i "s/^gtk-application-prefer-dark-theme.*/gtk-application-prefer-dark-theme=$GTK_DARK/" "$GTK3_INI"
  else
    sed -i "/^\[Settings\]/a gtk-application-prefer-dark-theme=$GTK_DARK" "$GTK3_INI"
  fi
else
  printf '[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$GTK_DARK" >> "$GTK3_INI"
fi

# ---- Reload consumers --------------------------------------------------------
command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
pidof waybar >/dev/null 2>&1 && killall -SIGUSR2 waybar 2>/dev/null || true
if pidof ghostty >/dev/null 2>&1; then
  for pid in $(pidof ghostty); do kill -SIGUSR2 "$pid" 2>/dev/null || true; done
fi
command -v swaync-client >/dev/null && swaync-client --reload-css >/dev/null 2>&1 || true

command -v notify-send >/dev/null && \
  notify-send -u low "Theme: $MODE" "$(basename "$WALL")" || true
