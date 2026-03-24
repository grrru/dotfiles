local diagnostic_icons = {
  Error = ' ',
  Warn = ' ',
  Hint = ' ',
  Info = ' ',
}

if vim.g.have_nerd_font then diagnostic_icons = {
  Error = ' ',
  Warn = ' ',
  Hint = ' ',
  Info = ' ',
} end

return {
  {
    'goolord/alpha-nvim',
    config = function() require('alpha').setup(require('alpha.themes.dashboard').config) end,
  },
  {
    'rcarriga/nvim-notify',
    event = 'VeryLazy',
    opts = {
      background_colour = '#000000',
      render = 'compact',
      stages = 'static',
      timeout = 5000,
    },
  },
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
        if diag.error and diag.error > 0 then return ' ' .. diagnostic_icons.Error .. diag.error end
        if diag.warning and diag.warning > 0 then return ' ' .. diagnostic_icons.Warn .. diag.warning end
        return ''
      end
      opts.options.always_show_bufferline = true
      opts.options.show_close_icon = false
      opts.options.max_name_length = 30
    end,
  },
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
      'rcarriga/nvim-notify',
    },
    opts = {
      cmdline = {
        enabled = true,
        view = 'cmdline_popup',
      },
      messages = {
        enabled = true,
      },
      popupmenu = {
        enabled = true,
      },
      notify = {
        enabled = true,
        view = 'notify',
      },
      presets = {
        bottom_search = false,
        command_palette = true,
        long_message_to_split = true,
      },
    },
  },
}
