local M = {}

local wezterm = require("wezterm")

----------
-- Font --
----------
M.font = wezterm.font("FiraCode Nerd Font Mono")

------------------
-- Font options --
------------------
M.harfbuzz_features = {
    "liga",
    "cv02",
    "cv19",
    "cv25",
    "cv26",
    "cv28",
    "cv30",
    "cv32",
    "ss02",
    "ss03",
    "ss05",
    "ss07",
    "ss09",
    "zero",
}

--------------------
-- Font rendering --
--------------------
M.freetype_render_target = "Light"

------------------
-- Cursor style --
------------------
-- M.default_cursor_style = "BlinkingBar"

--------------------
-- Window options --
--------------------
M.window_background_opacity = 0.8
M.text_background_opacity = 1.0
-- M.window_background_image = ""
M.window_decorations = "RESIZE"
M.window_close_confirmation = "NeverPrompt"
M.use_resize_increments = false
M.enable_scroll_bar = false
M.adjust_window_size_when_changing_font_size = false
M.window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
}

-----------
-- Bell ---
-----------
M.audible_bell = "Disabled"
M.visual_bell = {}

-------------
-- Tab bar --
-------------
M.enable_tab_bar = false

--------------
-- Keybinds --
--------------
local function keybind(mods, key, action)
    if type(action) == "table" then
        action = wezterm.action(action)
    end

    return {
        mods = mods,
        key = key,
        action = action,
    }
end

M.disable_default_key_bindings = true
M.keys = {
    ---------------
    -- Clipboard --
    ---------------
    keybind("ALT", "c", { CopyTo = "Clipboard" }),
    keybind("ALT", "v", { PasteFrom = "Clipboard" }),

    ---------------
    -- Font size --
    ---------------
    keybind("ALT|SHIFT", "UpArrow", "IncreaseFontSize"),
    keybind("ALT|SHIFT", "DownArrow", "DecreaseFontSize"),

    ------------
    -- Scroll --
    ------------
    keybind("ALT", "u", { ScrollByPage = -1 }),
    keybind("ALT", "d", { ScrollByPage = 1 }),

    ------------
    -- Reload --
    ------------
    keybind("CTRL|SHIFT", "r", "ReloadConfiguration"),
}

-----------
-- Links --
-----------
M.hyperlink_rules = {
    -- -- Linkify things that look like URLs
    -- -- This is actually the default if you don't specify any hyperlink_rules
    -- {
    --  regex = "\\b\\w+://(?:[\\w.-]+)\\.[a-z]{2,15}\\S*\\b",
    --  format = "$0",
    -- },

    -- Linkify things that look like URLs
    {
        regex = "\\b\\w+://(?:www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b(?:[-a-zA-Z0-9()@:%_\\+.~#?&/=]*)",
        format = "$0",
    },

    -- linkify email addresses
    {
        regex = "\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b",
        format = "mailto:$0",
    },

    -- file:// URI
    {
        regex = "\\bfile://\\S*\\b",
        format = "$0",
    },
}

return M
