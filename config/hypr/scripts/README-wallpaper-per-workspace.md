# Per-workspace wallpapers (future)

Today `theme-switch.sh` swaps one wallpaper per mode on darkman dark/light.
To make each workspace (SUPER+1..10) have its own wallpaper, per mode:

## 1. Add images
Name them by workspace number in each mode dir:

    ~/Photos/Wallpapers/Light/1.jpg  2.jpg ... 10.jpg
    ~/Photos/Wallpapers/Dark/1.jpg   2.jpg ... 10.jpg

## 2. Make the resolver workspace-aware
In `theme-switch.sh`, replace the "Resolve wallpaper" block (the `find ... head -n1`)
with a lookup that takes a workspace arg, falling back to the first image:

    WS="${2:-$(hyprctl activeworkspace -j | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)}"
    WALL="$WALL_DIR/$WS.jpg"
    [ -f "$WALL" ] || WALL="$(find -L "$WALL_DIR" -maxdepth 1 -type f | sort | head -n1)"

(no jq: the grep/cut reads the active workspace id)

## 3. Repaint on workspace change (socket2 listener)
Add a small listener and start it from `hyprland.conf` with
`exec-once = ~/.config/hypr/scripts/ws-wallpaper-listener.sh &`:

    #!/usr/bin/env bash
    socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    socat -U - "UNIX-CONNECT:$socket" | while read -r line; do
      case "$line" in
        workspace\>\>*) ws="${line#workspace>>}"
          ~/.config/hypr/scripts/theme-switch.sh "$(darkman get)" "$ws" ;;
      esac
    done

This fires on every workspace change (number keys, scroll, prev/next).
darkman mode switches still call `theme-switch.sh <mode>` and will repaint
the current workspace from the new mode's set. Requires `socat`.

## Notes
- Skip the wallust regen on plain workspace switches if it feels heavy
  (gate `wallust run` behind "mode changed since last run").
- Monitors are hardcoded as `DP-1,DP-2` in `theme-switch.sh`.
