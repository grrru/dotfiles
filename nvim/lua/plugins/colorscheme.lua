local theme = "catppuccin"
local mode_file = vim.fn.expand("~/.theme_mode")
local watcher

local function apply_mode(mode)
  if mode ~= "light" and mode ~= "dark" then
    return
  end

  if vim.o.background == mode then
    return
  end

  vim.o.background = mode
  if vim.g.colors_name == theme then
    vim.cmd.colorscheme(theme)
  end
end

local function load_mode()
  if vim.fn.filereadable(mode_file) == 0 then
    return
  end

  local mode = (vim.fn.readfile(mode_file, "", 1)[1] or ""):lower()

  apply_mode(mode)
end

local function watch_mode()
  if watcher or vim.fn.has("nvim-0.10") == 0 then
    return
  end

  watcher = vim.uv.new_fs_event()

  if not watcher then
    return
  end

  watcher:start(mode_file, {}, function()
    vim.schedule(load_mode)
  end)
end

load_mode()
watch_mode()

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      styles = {
        comments = {},
        conditionals = {},
        loops = {},
        functions = { "italic" },
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = { "italic" },
        properties = {},
        types = { "italic" },
        operators = {},
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
