-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", "<A-k>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<A-j>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<A-h>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<A-l>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

map("n", "<leader>bh", "<cmd>BufferLineMovePrev<cr>", { desc = "Move buffer left" })
map("n", "<leader>bl", "<cmd>BufferLineMoveNext<cr>", { desc = "Move buffer right" })

vim.api.nvim_create_user_command("WhichKeyRepair", function()
  local ok, triggers = pcall(require, "which-key.triggers")
  if not ok then
    vim.notify("which-key is not available", vim.log.levels.WARN)
    return
  end

  -- suspended 상태 강제 초기화 후 재연결 (매크로 녹화 등으로 suspend된 채 복구 안 된 경우)
  triggers.suspended = {}
  for _, mode in ipairs({ "n", "v", "x", "o" }) do
    pcall(triggers.attach, mode)
  end

  vim.notify("WhichKey repaired", vim.log.levels.INFO)
end, { desc = "Repair which-key trigger (clear suspended state)" })
