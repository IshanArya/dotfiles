#!/usr/bin/env bash
# Waybar cava visualizer: renders raw cava output as unicode block bars.

bar="▁▂▃▄▅▆▇█"
dict="s/;//g"

# build sed dict mapping 0-7 -> block chars
i=0
while [ $i -lt ${#bar} ]; do
    dict="${dict};s/$i/${bar:$i:1}/g"
    i=$((i + 1))
done

config_file="$HOME/.config/waybar/scripts/cava_config"

# write a temporary cava config (raw ascii output, 10 bars)
cat > "$config_file" <<EOF
[general]
bars = 10
framerate = 30

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

# run cava and translate each line of digits into block chars
cava -p "$config_file" | sed -u "$dict"
