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

# ---- Resolve Wayland display -------------------------------------------------
# If this hook runs before the compositor exported WAYLAND_DISPLAY (e.g. a
# service-manager race at login), awww would silently default to "wayland-0" and
# spawn a stray daemon on the wrong socket (which then core-dumps). Derive the
# live display from the running Hyprland instance instead of guessing.
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  if command -v hyprctl >/dev/null && hyprctl instances -j >/dev/null 2>&1; then
    # Hyprland names its socket after the instance: wayland-<n> on most setups.
    for sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/wayland-[0-9]*; do
      [[ -S "$sock" ]] || continue
      WAYLAND_DISPLAY="$(basename "$sock")"
      break
    done
  fi
fi
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  command -v notify-send >/dev/null && \
    notify-send -u critical "theme-switch" "WAYLAND_DISPLAY unset; aborting"
  echo "theme-switch: WAYLAND_DISPLAY unset and could not be resolved" >&2
  exit 1
fi
export WAYLAND_DISPLAY

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
# Maintain a stable pointer to the active wallpaper (used by hyprlock, etc.).
ln -sfn "$WALL" "$HOME/.config/hypr/.current-wallpaper"

# Only start a daemon if none is reachable on THIS display's socket. Checking
# `awww query` (not just pgrep) avoids spawning a duplicate when a daemon exists
# but on a different socket, and confirms the daemon is actually responsive.
if ! awww query >/dev/null 2>&1; then
  awww-daemon &
  for _ in {1..20}; do awww query >/dev/null 2>&1 && break; sleep 0.1; done
fi
if awww query >/dev/null 2>&1; then
  awww img -o "$MONITORS" "$WALL" "${TRANSITION[@]}" || \
    awww img "$WALL" "${TRANSITION[@]}" || true
else
  command -v notify-send >/dev/null && \
    notify-send -u critical "theme-switch" "awww-daemon unreachable on $WAYLAND_DISPLAY"
  echo "theme-switch: awww-daemon unreachable on $WAYLAND_DISPLAY" >&2
fi

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
