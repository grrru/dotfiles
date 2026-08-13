vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    error("Error cloning lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Machine-local plugin specs (git-ignored), e.g. extra colorschemes referenced
-- from theme.conf. Imported only when the directory exists.
local spec = {
  { import = "plugins" },
}
if vim.fn.isdirectory(vim.fn.stdpath("config") .. "/lua/local/plugins") == 1 then
  table.insert(spec, { import = "local.plugins" })
end

require("lazy").setup({
  spec = spec,
  defaults = {
    lazy = true,
    version = false,
  },
  install = { colorscheme = { "catppuccin", "habamax" } },
  checker = {
    enabled = true,
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- Colorschemes are loaded by now (lazy = false), so pick the one this machine
-- wants for the current light/dark mode.
require("config.theme").setup()
