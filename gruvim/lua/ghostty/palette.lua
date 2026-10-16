-- Colors for the `ghostty` colorscheme (colors/ghostty.lua) and its lualine
-- theme (lua/lualine/themes/ghostty.lua).
--
-- The terminal colors are Ghostty's built-in defaults, the ones a config with
-- no `theme` gets (`ghostty +show-config --default`): its own background and
-- foreground, and Tomorrow Night's 16 ANSI colors. Edit them here and run
-- `:colorscheme ghostty` again to see the change.
local M = {
  bg = "#282c34",
  fg = "#ffffff",

  black = "#1d1f21",
  red = "#cc6666",
  green = "#b5bd68",
  yellow = "#f0c674",
  blue = "#81a2be",
  magenta = "#b294bb",
  cyan = "#8abeb7",
  white = "#c5c8c6",

  bright_black = "#666666",
  bright_red = "#d54e53",
  bright_green = "#b9ca4a",
  bright_yellow = "#e7c547",
  bright_blue = "#7aa6da",
  bright_magenta = "#c397d8",
  bright_cyan = "#70c0b1",
  bright_white = "#eaeaea",
}

-- Ghostty's palette has no orange, and bright black is too dim to read
-- comments in, so these two come from Tomorrow Night, where the ANSI colors
-- above come from too.
M.orange = "#de935f"
M.comment = "#969896"

-- UI shades, from darker than bg up towards the comment gray.
M.bg_dark = "#21252b" -- floats, popup menu, statusline, tabline
M.bg_light = "#2f333d" -- cursor line, color column, folds
M.bg_visual = "#3e4451" -- selection, window separators
M.bg_bright = "#4b5263" -- scrollbar thumb, whitespace characters
M.line_nr = "#5c6370"

return M
