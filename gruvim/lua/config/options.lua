local opt = vim.opt

opt.relativenumber = true
opt.number = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
if vim.env.HERDR_ENV == "1" then
  -- Herdr forwards OSC 52 writes from its panes to the outer terminal, but Neovim
  -- cannot detect OSC 52 support inside a Herdr pane and ends up with no clipboard.
  -- Yank over OSC 52, and paste the last yank instead of asking the terminal for
  -- its clipboard: over ssh the OSC 52 answer can arrive in pieces and end up as
  -- typed keys.
  local osc52 = require("vim.ui.clipboard.osc52")
  local last = {} ---@type table<string, {[1]:string[], [2]:string}>
  local function copy(reg)
    local write = osc52.copy(reg)
    return function(lines, regtype)
      last[reg] = { lines, regtype }
      write(lines, regtype)
    end
  end
  local function paste(reg)
    return function()
      return last[reg] or { {}, "v" }
    end
  end
  vim.g.clipboard = {
    name = "herdr-osc52",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
  }
end

opt.clipboard = "unnamedplus"
opt.spelllang = { "en", "cjk" }
opt.timeoutlen = 500
opt.termguicolors = true
opt.signcolumn = "yes"
opt.updatetime = 200
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.splitbelow = true
opt.splitright = true
opt.splitkeep = "screen"
opt.scrolloff = 5
opt.sidescrolloff = 8
opt.jumpoptions = { "view", "clean" }
opt.cursorline = true
opt.guicursor:append("t:blinkon0")
opt.sessionoptions:remove("blank")
-- plugins/session.lua stores the per-tab buffer lists in a global
opt.sessionoptions:append("globals")
opt.winborder = "rounded"
