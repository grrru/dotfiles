-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Preserve view when switching buffers
vim.api.nvim_create_autocmd("BufLeave", {
  callback = function()
    vim.b._saved_view = vim.fn.winsaveview()
  end,
})
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local saved = vim.b._saved_view
    if saved then
      vim.schedule(function()
        vim.fn.winrestview(saved)
      end)
    end
  end,
})
