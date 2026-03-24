local function delete_buffer_keep_layout()
  local current_buf = vim.api.nvim_get_current_buf()
  local current_win = vim.api.nvim_get_current_win()

  if vim.bo[current_buf].filetype == 'neo-tree' then return end

  local target_buf
  local alternate_buf = vim.fn.bufnr '#'
  if alternate_buf > 0 and vim.api.nvim_buf_is_valid(alternate_buf) and vim.bo[alternate_buf].buflisted then
    target_buf = alternate_buf
  else
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if buf ~= current_buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
        target_buf = buf
        break
      end
    end
  end

  if target_buf then
    vim.api.nvim_win_set_buf(current_win, target_buf)
  else
    vim.cmd.enew()
  end

  vim.api.nvim_buf_delete(current_buf, {})
end

vim.keymap.set('n', '<leader>x', delete_buffer_keep_layout, { desc = 'delete Buffer' })
vim.keymap.set('n', 'L', '<cmd>bnext<CR>', { desc = '[N]ext Buffer' })
vim.keymap.set('n', 'H', '<cmd>bprevious<CR>', { desc = '[P]revious Buffer' })
