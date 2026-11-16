-- Look & feel: tiling layout, gaps, borders, animations, rules.
-- Colors come from wallust (COLORS, loaded in hyprland.lua).
local c = COLORS
local hy3 = PLUGINS.hy3

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,

        col = {
            active_border = { colors = { c.color6, c.color14 }, angle = 45 },
            inactive_border = c.color0,
        },

        -- hy3 = true i3/sway-style manual tiling tree. Falls back to dwindle
        -- until hyprpm has loaded hy3 (first parse at login), or if hy3 fails
        -- to build for this Hyprland version.
        layout = hy3 and "hy3" or "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },

    decoration = {
        rounding = 4,

        blur = {
            enabled = true,
            size = 4,
            passes = 2,
        },

        shadow = {
            enabled = true,
            range = 8,
            render_power = 2,
        },
    },

    -- Subtle animations; set enabled = false for instant, i3-like snappiness.
    animations = {
        enabled = true,
    },
})

hl.curve("easeOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.animation({ leaf = "windows",    enabled = true, speed = 3, bezier = "easeOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOut" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3, bezier = "easeOut" })

-- hy3 options. Only set once the plugin is loaded, otherwise Hyprland reports
-- unknown config keys. Tab backgrounds are translucent so blur shows through.
if hy3 then
    hl.config({
        plugin = {
            hy3 = {
                -- When a node is removed leaving a lone group, keep it only if
                -- its parent is a tab group (i3-ish behavior).
                node_collapse_policy = 2,
                -- Inset for a single-window group.
                group_inset = 8,
                -- Don't auto-tab the first window on a workspace.
                tab_first_window = false,

                tabs = {
                    height = 18,
                    padding = 4,
                    from_top = false,
                    radius = 4,
                    border_width = 2,
                    render_text = true,
                    text_center = true,
                    text_font = "Sans",
                    text_height = 9,
                    text_padding = 4,

                    blur = true,
                    opacity = 0.9,

                    colors = {
                        -- active = focused tab on the focused monitor
                        active = "rgba(B4954066)",
                        active_border = c.color14,
                        active_text = c.foreground,

                        -- focused node inside an unfocused container
                        focused = "rgba(42464A66)",
                        focused_border = c.color6,
                        focused_text = c.foreground,

                        -- inactive tabs
                        inactive = "rgba(181B1E99)",
                        inactive_border = c.color0,
                        inactive_text = c.color7,

                        -- urgent
                        urgent = "rgba(7A717399)",
                        urgent_border = c.color3,
                        urgent_text = c.foreground,
                    },
                },

                -- Manual i3-style splitting (no autotiling).
                autotile = {
                    enable = false,
                },
            },
        },
    })
end

-- hyprEasymotion: jump-to-window labels. Wallust-themed, translucent + blurred.
-- DISABLED as of 2026-11-15: no build supports Hyprland 0.57 (still uses the
-- removed Hyprlang config API). It was removed from hyprpm; previously used:
--   hyprpm add https://github.com/prtsie/hyprland-easymotion 1c9110e1e02047fa4e2a5ca6ec3e9bbf26ad3700
--   (prtsie fork, "fix: Hyprland 0.56.0 API compatibility"; upstream is zakk4223/hyprland-easymotion)
-- These options are the old `plugin { easymotion { ... } }` block translated
-- 1:1; key names may change once the plugin is ported to Lua. bgcolor used
-- $backgroundAlpha (wallust bg @ ~70%) so blur shows through; motionkeys put
-- home-row first (';' is the trigger key, so it's excluded).
if PLUGINS.easymotion then
    hl.config({
        plugin = {
            easymotion = {
                textsize = 42,
                textcolor = c.foreground,
                bgcolor = c.backgroundAlpha,
                blur = 1,
                blurA = 1.0,
                xray = 0,
                textfont = "Sans",
                textpadding = "18 30 18 30",
                bordersize = 1,
                bordercolor = c.color0,
                rounding = 14,
                fullscreen_action = "none",
                motionkeys = "asdfghjklqwertyuiopzxcvbnm",
                motionlabels = "ASDFGHJKLQWERTYUIOPZXCVBNM",
            },
        },
    })
end

-- Frosted-glass blur for translucent rofi launcher / cheatsheet.
hl.layer_rule({ name = "rofi-blur", match = { namespace = "rofi" }, blur = true, ignore_alpha = 0 })

-- Slightly translucent editor so the global blur shows through (ghostty-like).
hl.window_rule({ name = "cursor-opacity", match = { class = "^(cursor)$" }, opacity = "0.90 0.85" })
