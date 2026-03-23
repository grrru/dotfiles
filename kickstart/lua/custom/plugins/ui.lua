local diagnostic_icons = {
  Error = ' ',
  Warn = ' ',
  Hint = ' ',
  Info = ' ',
}

if vim.g.have_nerd_font then
  diagnostic_icons = {
    Error = ' ',
    Warn = ' ',
    Hint = ' ',
    Info = ' ',
  }
end

return {
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_c = {
        {
          'filename',
          file_status = true,
          path = 0,
        },
      }
    end,
  },
  {
    'akinsho/bufferline.nvim',
    version = '*',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.indicator = { style = 'none' }
      opts.options.diagnostics = 'nvim_lsp'
      opts.options.diagnostics_indicator = function(_, _, diag)
        if diag.error and diag.error > 0 then
          return ' ' .. diagnostic_icons.Error .. diag.error
        end
        if diag.warning and diag.warning > 0 then
          return ' ' .. diagnostic_icons.Warn .. diag.warning
        end
        return ''
      end
      opts.options.always_show_bufferline = true
      opts.options.show_close_icon = false
      opts.options.max_name_length = 30
    end,
  },
}
