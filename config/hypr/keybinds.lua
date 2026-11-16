-- =============================================================================
-- i3/sway-style keybindings for Hyprland (Lua)
--
-- Convention (scripts/keybinds_parser.py depends on it, keep it):
--   bind("MODS + KEY", "Description" | nil, dispatcher, opts?)
--   * keys are LITERAL strings ("SUPER + h"), not concatenations
--   * section headers are comments like:  -- --- Screenshots -----------
--   * binds generated in loops get a  -- cheatsheet: KEYS | Description  line
-- =============================================================================

local hy3 = PLUGINS.hy3
local smw = PLUGINS.smw
local dsp = hl.dsp

local terminal    = "ghostty"
local fileManager = "thunar"
local menu        = "rofi -show drun"
local scripts     = "$HOME/.config/hypr/scripts"

local function bind(keys, desc, dispatcher, opts)
    opts = opts or {}
    if desc then opts.description = desc end
    return hl.bind(keys, dispatcher, opts)
end

-- --- Apps & session ----------------------------------------------------------
bind("SUPER + Return",         "Terminal",               dsp.exec_cmd(terminal))
bind("SUPER + D",              "Application launcher",   dsp.exec_cmd(menu))
bind("SUPER + SHIFT + Return", "File manager",           dsp.exec_cmd(fileManager))
bind("SUPER + SHIFT + Q",      "Kill active window",     hy3 and hy3.kill_active() or dsp.window.close())
bind("SUPER + SHIFT + C",      "Reload Hyprland config", dsp.reload_config())
bind("SUPER + SHIFT + E",      "Exit / logout",
    dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- --- Lock screen -------------------------------------------------------------
-- K860 lock key is remapped to F13 by keyd (alt+l -> f13). Both go through
-- loginctl lock-session, which hypridle turns into hyprlock.
bind("code:191",          "Lock screen", dsp.exec_cmd("loginctl lock-session"))
bind("SUPER + SHIFT + X", "Lock screen", dsp.exec_cmd("loginctl lock-session"))

-- --- Cheat sheet -------------------------------------------------------------
bind("SUPER + slash",         "Search all keybinds", dsp.exec_cmd(scripts .. "/cheatsheet-search.sh"))
bind("SUPER + SHIFT + slash", "Quick cheat sheet",   dsp.exec_cmd(scripts .. "/cheatsheet-quick.sh"))

-- --- Window state ------------------------------------------------------------
bind("SUPER + F",             "Fullscreen",               dsp.window.fullscreen({ mode = "fullscreen" }))
bind("SUPER + SHIFT + F",     "Maximize (keep gaps/bar)", dsp.window.fullscreen({ mode = "maximized" }))
bind("SUPER + SHIFT + SPACE", "Toggle floating",          dsp.window.float({ action = "toggle" }))
bind("SUPER + P",             "Toggle pseudotile",        dsp.window.pseudo())

-- =============================================================================
-- hy3 dispatcher notes:
--   * visible = true on move_focus  -> focus jumps between VISIBLE windows only,
--     treating a tab group as one unit (so Super+Tab is what cycles within it).
--   * once = true on move_window    -> window moves to the neighboring group
--     WITHOUT descending into it, so windows don't auto-join groups as tabs.
--   Without hy3 loaded these fall back to Hyprland's built-in focus/move.
-- =============================================================================
local dirs = { l = "left", d = "down", u = "up", r = "right" }
local function focus(d)
    return hy3 and hy3.move_focus(d, { visible = true }) or dsp.focus({ direction = dirs[d] })
end
local function move(d)
    return hy3 and hy3.move_window(d, { once = true }) or dsp.window.move({ direction = dirs[d] })
end

-- --- Focus (vim keys + arrows) ----------------------------------------------
bind("SUPER + h",     "Focus left",  focus("l"))
bind("SUPER + j",     "Focus down",  focus("d"))
bind("SUPER + k",     "Focus up",    focus("u"))
bind("SUPER + l",     "Focus right", focus("r"))
bind("SUPER + left",  "Focus left (arrow)",  focus("l"))
bind("SUPER + down",  "Focus down (arrow)",  focus("d"))
bind("SUPER + up",    "Focus up (arrow)",    focus("u"))
bind("SUPER + right", "Focus right (arrow)", focus("r"))

-- Easymotion: only bound if the plugin loads and exposes a Lua API
-- (it is hyprlang-only upstream and does not build for Hyprland 0.57; see
-- looknfeel.lua for how it was installed). The Lua call below is a GUESS at
-- what a port would look like; adjust to the real API when one exists.
-- Old hyprlang bind, for reference:
--   bindd = $mainMod, semicolon, Easymotion jump to window, easymotion, action:hyprctl dispatch focuswindow address:{}
if PLUGINS.easymotion and PLUGINS.easymotion.easymotion then
    bind("SUPER + semicolon", "Easymotion jump to window (if plugin loaded)",
        PLUGINS.easymotion.easymotion({ action = "hyprctl dispatch 'hl.dsp.focus({ window = \"address:{}\" })'" }))
end

-- --- Move window (vim keys + arrows) ----------------------------------------
bind("SUPER + SHIFT + h",     "Move window left",  move("l"))
bind("SUPER + SHIFT + j",     "Move window down",  move("d"))
bind("SUPER + SHIFT + k",     "Move window up",    move("u"))
bind("SUPER + SHIFT + l",     "Move window right", move("r"))
bind("SUPER + SHIFT + left",  "Move window left (arrow)",  move("l"))
bind("SUPER + SHIFT + down",  "Move window down (arrow)",  move("d"))
bind("SUPER + SHIFT + up",    "Move window up (arrow)",    move("u"))
bind("SUPER + SHIFT + right", "Move window right (arrow)", move("r"))

-- --- Move window across monitors --------------------------------------------
-- hy3's move_window stays within a workspace's tree, so use Hyprland's built-in
-- window.move with a monitor direction to send the window to the other screen.
bind("SUPER + SHIFT + comma",  "Move window to left monitor",  dsp.window.move({ monitor = "l" }))
bind("SUPER + SHIFT + period", "Move window to right monitor", dsp.window.move({ monitor = "r" }))

if hy3 then
    -- --- Split (hy3 make_group) ---------------------------------------------
    bind("SUPER + E", "Split opposite direction", hy3.make_group("opposite"))
    bind("SUPER + V", "Split vertical",           hy3.make_group("v"))
    bind("SUPER + B", "Split horizontal",         hy3.make_group("h"))

    -- --- Tabbed groups (i3 tabbed/stacked equivalent) ------------------------
    bind("SUPER + W",           "Toggle tab group", hy3.change_group("toggletab"))
    bind("SUPER + Tab",         "Next tab",         hy3.focus_tab({ direction = "r", wrap = true }))
    bind("SUPER + SHIFT + Tab", "Previous tab",     hy3.focus_tab({ direction = "l", wrap = true }))
    -- Change the focused group's layout (i3-style layout toggles)
    bind("SUPER + ALT + h", "Untab group",            hy3.change_group("untab"))
    bind("SUPER + ALT + l", "Flip split orientation", hy3.change_group("opposite"))
end

-- --- Resize mode (i3 "resize" submap) ----------------------------------------
-- Super+R enters resize mode: h/j/k/l or arrows resize; Esc/Return to exit.
bind("SUPER + R", "Enter resize mode", dsp.submap("resize"))
hl.define_submap("resize", function()
    local function rs(x, y) return dsp.window.resize({ x = x, y = y, relative = true }) end
    hl.bind("h",     rs(-40, 0), { repeating = true })
    hl.bind("j",     rs(0, 40),  { repeating = true })
    hl.bind("k",     rs(0, -40), { repeating = true })
    hl.bind("l",     rs(40, 0),  { repeating = true })
    hl.bind("left",  rs(-40, 0), { repeating = true })
    hl.bind("down",  rs(0, 40),  { repeating = true })
    hl.bind("up",    rs(0, -40), { repeating = true })
    hl.bind("right", rs(40, 0),  { repeating = true })
    hl.bind("escape", dsp.submap("reset"))
    hl.bind("Return", dsp.submap("reset"))
end)

-- --- Workspaces 1-10 (unified across both monitors) --------------------------
-- split-monitor-workspaces + link_monitors (see hyprland.lua) switches BOTH
-- monitors to "desktop N" together. Each monitor keeps its own 1-10 numbering
-- internally (DP-1: 1-10, DP-2: 11-20), but you always address them as 1-10.
-- Moving is silent and stays on the focused monitor's side (smw uses hy3's
-- move_to_workspace automatically when hy3 is loaded).
-- cheatsheet: SUPER + 1..0 | Switch to workspace 1-10
-- cheatsheet: SUPER + SHIFT + 1..0 | Move window to workspace 1-10 (silent)
for i = 1, 10 do
    local key = tostring(i % 10)
    if smw then
        hl.bind("SUPER + " .. key,         smw.workspace(tostring(i)))
        hl.bind("SUPER + SHIFT + " .. key, smw.move_to_workspace_silent(tostring(i)))
    else
        hl.bind("SUPER + " .. key,         dsp.focus({ workspace = i }))
        hl.bind("SUPER + SHIFT + " .. key, dsp.window.move({ workspace = i, follow = false }))
    end
end

-- Cycle workspaces (i3 prev/next). With link_monitors both monitors cycle together.
local prev_ws = smw and smw.cycle_workspaces("prev") or dsp.focus({ workspace = "m-1" })
local next_ws = smw and smw.cycle_workspaces("next") or dsp.focus({ workspace = "m+1" })
bind("SUPER + CTRL + h",     "Previous workspace", prev_ws)
bind("SUPER + CTRL + l",     "Next workspace",     next_ws)
bind("SUPER + CTRL + left",  "Previous workspace (arrow)", prev_ws)
bind("SUPER + CTRL + right", "Next workspace (arrow)",     next_ws)

-- Special / scratchpad workspace (i3-like)
bind("SUPER + minus",         "Toggle scratchpad",         dsp.workspace.toggle_special("scratch"))
bind("SUPER + SHIFT + minus", "Move window to scratchpad", dsp.window.move({ workspace = "special:scratch" }))

-- --- Mouse -------------------------------------------------------------------
bind("SUPER + mouse_down", "Next workspace (scroll)",     next_ws)
bind("SUPER + mouse_up",   "Previous workspace (scroll)", prev_ws)
bind("SUPER + mouse:272",  "Move window (drag)",   dsp.window.drag(),   { mouse = true })
bind("SUPER + mouse:273",  "Resize window (drag)", dsp.window.resize(), { mouse = true })

-- --- Audio / media -----------------------------------------------------------
-- swayosd-client both changes the value AND shows the macOS-style OSD popup.
-- repeating = repeat while held; locked = also works on the lock screen.
local held   = { repeating = true, locked = true }
local locked = { locked = true }
bind("XF86AudioRaiseVolume", "Volume up", dsp.exec_cmd("swayosd-client --output-volume raise --max-volume 100"), held)
bind("XF86AudioLowerVolume", "Volume down", dsp.exec_cmd("swayosd-client --output-volume lower --max-volume 100"), held)
bind("XF86AudioMute",        "Mute output", dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), locked)
bind("XF86AudioMicMute",     "Mute microphone", dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),  locked)
bind("XF86AudioPlay",        "Play / pause", dsp.exec_cmd("swayosd-client --playerctl play-pause"),      locked)
bind("XF86AudioNext",        "Next track", dsp.exec_cmd("swayosd-client --playerctl next"),            locked)
bind("XF86AudioPrev",        "Previous track", dsp.exec_cmd("swayosd-client --playerctl prev"),            locked)

-- --- Screenshots -------------------------------------------------------------
local shot = "~/Photos/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png"
bind("Print",                 "Screenshot region to file",       dsp.exec_cmd('grim -g "$(slurp)" ' .. shot))
bind("SUPER + Print",         "Screenshot full screen",          dsp.exec_cmd("grim " .. shot))
bind("SUPER + SHIFT + Print", "Screenshot region annotate",      dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
bind("SUPER + SHIFT + S",     "Screenshot region to clipboard",  dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
