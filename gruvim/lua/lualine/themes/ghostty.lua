-- lualine theme for the `ghostty` colorscheme. plugins/ui.lua sets
-- `theme = "auto"`, which loads the theme named after the colorscheme.
local p = require("ghostty.palette")

local function mode(color)
  return {
    a = { fg = p.bg, bg = color, gui = "bold" },
    b = { fg = color, bg = p.bg_visual },
    c = { fg = p.white, bg = p.bg_dark },
  }
end

return {
  normal = mode(p.blue),
  insert = mode(p.green),
  visual = mode(p.magenta),
  replace = mode(p.red),
  command = mode(p.yellow),
  terminal = mode(p.cyan),
  inactive = {
    a = { fg = p.comment, bg = p.bg_dark },
    b = { fg = p.comment, bg = p.bg_dark },
    c = { fg = p.comment, bg = p.bg_dark },
  },
}
