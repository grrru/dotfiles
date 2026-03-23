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
