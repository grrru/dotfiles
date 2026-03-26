-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("i", "jk", "<Esc>", { desc = "Exit insert mode" })
map("i", "kj", "<Esc>", { desc = "Exit insert mode" })

map("n", "<A-k>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<A-j>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<A-h>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<A-l>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

vim.api.nvim_create_user_command("WhichKeyRepair", function()
  local buf = vim.api.nvim_get_current_buf()
  local ok, wkbuf = pcall(require, "which-key.buf")
  if not ok then
    vim.notify("which-key.buf is not available", vim.log.levels.WARN)
    return
  end
  wkbuf.clear({ buf = buf, mode = "n" })
  wkbuf.get({ buf = buf, mode = "n", update = true })
end, { desc = "Rebuild normal-mode which-key triggers for the current buffer" })
