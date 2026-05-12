local function augroup(name)
  return vim.api.nvim_create_augroup("gruvim_" .. name, { clear = true })
end

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Resize splits on window resize
vim.api.nvim_create_autocmd("VimResized", {
  group = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Go to last location when opening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("last_loc"),
  callback = function(event)
    local exclude = { "gitcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close certain filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "help",
    "lspinfo",
    "notify",
    "qf",
    "startuptime",
    "checkhealth",
    "man",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Per-filetype indentation
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("indent"),
  pattern = {
    "lua",
    "javascript",
    "typescript",
    "typescriptreact",
    "javascriptreact",
    "json",
    "yaml",
    "html",
    "css",
    "sh",
  },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
  end,
})

-- Preserve view when switching buffers
local preserve_view_group = augroup("preserve_view")
vim.api.nvim_create_autocmd("BufLeave", {
  group = preserve_view_group,
  callback = function()
    vim.b._saved_view = vim.fn.winsaveview()
  end,
})
vim.api.nvim_create_autocmd("BufEnter", {
  group = preserve_view_group,
  callback = function()
    local saved = vim.b._saved_view
    if saved then
      vim.fn.winrestview(saved)
    end
  end,
})

-- Show the dashboard again after deleting the last file buffer.
vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = augroup("dashboard_on_empty"),
  callback = function()
    vim.schedule(function()
      if not package.loaded["snacks"] or vim.bo.filetype == "snacks_dashboard" then
        return
      end

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
          return
        end
      end

      local buf = vim.api.nvim_get_current_buf()
      local is_empty = vim.bo[buf].buftype == ""
        and vim.api.nvim_buf_get_name(buf) == ""
        and not vim.bo[buf].modified
        and vim.api.nvim_buf_line_count(buf) == 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""

      if is_empty then
        Snacks.dashboard.open({ buf = buf, win = 0 })
      end
    end)
  end,
})

-- Auto-create parent directories on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("auto_create_dir"),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})
