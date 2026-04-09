return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = {
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.globalstatus = true
      opts.sections = opts.sections or {}
      opts.sections.lualine_c = {
        {
          'filename',
          file_status = true,
          path = 0,
        },
      }
      opts.sections.lualine_z = { 'encoding' }
    end,
  },
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = {
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.indicator = {
        style = 'none',
      }
      opts.options.offsets = {
        {
          filetype = 'snacks_picker_list',
          text = 'Explorer',
          text_align = 'left',
          separator = true,
        },
      }
      opts.options.diagnostics = 'nvim_lsp'
      opts.options.diagnostics_indicator = function(_, _, diag)
        if diag.error then return ' E' .. diag.error end
        if diag.warning then return ' W' .. diag.warning end
        return ''
      end
      opts.options.always_show_bufferline = true
      opts.options.show_close_icon = false
      opts.options.max_name_length = 30
    end,
  },
}
