local opt = vim.opt

opt.relativenumber = true
opt.number = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
-- Neovim's built-in tmux clipboard provider reads the clipboard by asking the
-- outer terminal for it (`tmux refresh-client -l`). Ghostty answers with an
-- OSC 52 sequence that arrives over ssh in pieces; tmux abandons a partial
-- escape sequence after `escape-time` and hands the rest to the focused pane as
-- keystrokes, so merely starting nvim typed base64 into the buffer and ran
-- whatever the leading bytes happened to be bound to. Raising `escape-time`
-- only narrows the race, so read from the tmux buffer instead and never ask the
-- terminal. Yanks still reach the system clipboard: `load-buffer -w` pushes
-- them out over OSC 52, which is a write and needs no reply.
if vim.env.TMUX then
  local copy = { "tmux", "load-buffer", "-w", "-" }
  -- A tmux server with nothing copied yet has no buffer at all, and
  -- `save-buffer` then fails; swallow that so a first paste is empty instead of
  -- an error message.
  local paste = { "sh", "-c", "tmux save-buffer - 2>/dev/null || true" }
  vim.g.clipboard = {
    name = "tmux-quiet",
    copy = { ["+"] = copy, ["*"] = copy },
    paste = { ["+"] = paste, ["*"] = paste },
    cache_enabled = true,
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
opt.winborder = "rounded"
