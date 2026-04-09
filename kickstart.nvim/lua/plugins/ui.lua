return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = {
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    opts = function(_, opts)
      local ok_snacks, snacks = pcall(require, 'snacks')
      local function snacks_color(name, fallback)
        if ok_snacks and snacks.util and snacks.util.color then
          return { fg = snacks.util.color(name) }
        end
        return { fg = fallback }
      end

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
      opts.sections.lualine_x = {
        ok_snacks and snacks.profiler and snacks.profiler.status() or function() return '' end,
        {
          function() return require('noice').api.status.command.get() end,
          cond = function() return package.loaded['noice'] and require('noice').api.status.command.has() end,
          color = function() return snacks_color('Statement', '#a6da95') end,
        },
        {
          function() return require('noice').api.status.mode.get() end,
          cond = function() return package.loaded['noice'] and require('noice').api.status.mode.has() end,
          color = function() return snacks_color('Constant', '#f5a97f') end,
        },
        {
          function() return '  ' .. require('dap').status() end,
          cond = function() return package.loaded['dap'] and require('dap').status() ~= '' end,
          color = function() return snacks_color('Debug', '#c6a0f6') end,
        },
        {
          require('lazy.status').updates,
          cond = require('lazy.status').has_updates,
          color = function() return snacks_color('Special', '#8aadf4') end,
        },
        {
          'diff',
          symbols = {
            added = '+',
            modified = '~',
            removed = '-',
          },
          source = function()
            local gitsigns = vim.b.gitsigns_status_dict
            if gitsigns then
              return {
                added = gitsigns.added,
                modified = gitsigns.changed,
                removed = gitsigns.removed,
              }
            end
          end,
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
          filetype = 'snacks_layout_box',
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
