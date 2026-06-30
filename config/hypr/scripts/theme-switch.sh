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
  dark)  SET_DIR="Dark";  GTK_DARK=1; GTK_SCHEME="prefer-dark"  ;;
  light) SET_DIR="Light"; GTK_DARK=0; GTK_SCHEME="prefer-light" ;;
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

# Wait for the daemon started by hyprland.conf (exec-once = awww-daemon --no-cache).
# Do NOT spawn our own daemon here: at login this script (via darkman's hook) runs
# concurrently with that exec-once, and a second awww-daemon races the first for the
# socket and SIGABRTs (leaving monitors on the solid-color fallback -> black
# wallpaper). awww has a single daemon per WAYLAND_DISPLAY; exec-once owns it.
# Poll `awww query` up to ~5s so we tolerate being launched before it's fully up.
for _ in {1..50}; do awww query >/dev/null 2>&1 && break; sleep 0.1; done
if awww query >/dev/null 2>&1; then
  # Apply the wallpaper, then VERIFY it actually took. At login the DRM outputs
  # may not be ready yet (esp. NVIDIA-only after disabling the iGPU: aquamarine
  # logs "atomic drm request: Device or resource busy"). In that window `awww img`
  # silently fails and the monitors stay on the solid-color fallback. We retry
  # until `awww query` no longer reports any output "currently displaying: color:"
  # (i.e. an image is shown), or we exhaust the attempts (~5s worst case).
  # Verify the CURRENT mode's wallpaper actually painted on every output, not
  # merely "some image" — at cold boot awww may be showing the cached previous-
  # mode image, which the old `! grep color:` check wrongly accepted, leaving the
  # wallpaper stuck on the prior mode. Retry through the NVIDIA DRM-not-ready
  # window until awww reports $WALL on each monitor (~10s worst case).
  IFS=',' read -ra _mons <<< "$MONITORS"
  _want=${#_mons[@]}
  for _attempt in {1..20}; do
    awww img -o "$MONITORS" "$WALL" "${TRANSITION[@]}" 2>/dev/null || \
      awww img "$WALL" "${TRANSITION[@]}" 2>/dev/null || true
    _shown=$(awww query 2>/dev/null | grep -Fc "currently displaying: image: $WALL")
    [[ "$_shown" -ge "$_want" ]] && break
    sleep 0.5
  done
else
  command -v notify-send >/dev/null && \
    notify-send -u critical "theme-switch" "awww-daemon unreachable on $WAYLAND_DISPLAY"
  echo "theme-switch: awww-daemon unreachable on $WAYLAND_DISPLAY" >&2
fi

# ---- Wallust palette ---------------------------------------------------------
# Regenerates all templates defined in ~/.config/wallust/wallust.toml.
command -v wallust >/dev/null && wallust run -s "$WALL" || true

# ---- gsettings color-scheme --------------------------------------------------
# Belt-and-suspenders for GTK4/libadwaita apps that read the color-scheme key
# directly. The XDG Settings portal is routed to darkman (see
# ~/.config/xdg-desktop-portal/hyprland-portals.conf), but keeping this key in
# sync avoids any stale 'prefer-dark' lingering for apps that bypass the portal.
command -v gsettings >/dev/null && \
  gsettings set org.gnome.desktop.interface color-scheme "$GTK_SCHEME" 2>/dev/null || true

# ---- GTK3 (Thunar et al.) dark/light toggle ----------------------------------
# GTK3 apps don't follow the XDG portal hint; they need this in settings.ini.
# Brave/GTK4 follow darkman via the XDG Settings portal (color-scheme).
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
