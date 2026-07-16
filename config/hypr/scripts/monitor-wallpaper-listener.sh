#!/usr/bin/env bash
# ==================================================
#  monitor-wallpaper-listener.sh
#  Re-assert the current wallpaper whenever Hyprland (re)creates an output.
#  Started once from hyprland.conf: exec-once = ...monitor-wallpaper-listener.sh
# ==================================================
#  Why this exists
#  ---------------
#  awww caches the last-displayed image PER OUTPUT and, when an output is
#  (re)connected/woken, spawns a client that reloads that cached image. On this
#  NVIDIA-only box the DRM outputs settle late (aquamarine: "atomic drm request:
#  Device or resource busy"), so awww's cache-restore can land AFTER
#  theme-switch.sh's paint and repaint the PREVIOUS mode — the login wallpaper
#  race. It also affects mid-session events: monitor DPMS off/on, cable reconnect.
#
#  This listener makes ~/.config/hypr/.current-wallpaper (maintained by
#  theme-switch.sh) the single source of truth on every output (re)creation.
#  It reacts to Hyprland's monitoraddedv2 event and re-issues `awww img` with an
#  INSTANT transition so the correct image wins deterministically.
#
#  Cost/safety
#  -----------
#  - Idle 0% CPU: blocked on a socket read; wakes only on Hyprland events.
#  - No feedback loop: `awww img` never adds/removes outputs, so it can't
#    retrigger monitoraddedv2.
#  - Lifecycle: socket2 closes when Hyprland exits, so this loop ends with the
#    session; exec-once restarts it next login. `hyprctl reload` does NOT re-run
#    exec-once, so no duplicate listeners.
#  - Graceful degradation: if this dies you're back to plain awww cache behavior
#    (never worse than without it). Requires `socat`.
set -uo pipefail

CURRENT_WALL="$HOME/.config/hypr/.current-wallpaper"
MONITORS="DP-1,DP-2"   # keep in sync with theme-switch.sh

command -v socat >/dev/null 2>&1 || {
  echo "monitor-wallpaper-listener: socat not installed; exiting" >&2
  exit 1
}

SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" || ! -S "$SOCK" ]]; then
  echo "monitor-wallpaper-listener: Hyprland event socket not found at $SOCK" >&2
  exit 1
fi

reassert() {
  # Resolve the wallpaper the current mode points at. If the pointer is missing
  # (first boot before theme-switch ran), do nothing — theme-switch owns setup.
  local wall
  wall="$(readlink -f "$CURRENT_WALL" 2>/dev/null)" || return 0
  [[ -n "$wall" && -f "$wall" ]] || return 0

  IFS=',' read -ra _mons <<< "$MONITORS"
  local want=${#_mons[@]}
  # awww's own cache-restore fires concurrently on this same event; retry a few
  # times (instant transition) until $wall is shown on every output, so whichever
  # paint lands last is the correct one.
  local i shown
  for ((i = 0; i < 6; i++)); do
    shown=$(awww query 2>/dev/null | grep -Fc "currently displaying: image: $wall")
    [[ "$shown" -ge "$want" ]] && return 0
    awww img -o "$MONITORS" "$wall" --transition-type none 2>/dev/null || \
      awww img "$wall" --transition-type none 2>/dev/null || true
    sleep 0.3
  done
}

# -U: connect as a client to Hyprland's event stream. Lines look like:
#   monitoraddedv2>>1,DP-1,LG Ultra HD
# We only care that SOME output was (re)created; reassert() covers all monitors.
socat -U - "UNIX-CONNECT:$SOCK" 2>/dev/null | while read -r line; do
  case "$line" in
    monitoraddedv2\>\>*|monitoradded\>\>*) reassert ;;
  esac
done
