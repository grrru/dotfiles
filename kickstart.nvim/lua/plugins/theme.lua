local active_theme = 'catppuccin'

return {
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    opts = {
      styles = {
        comments = { italic = false },
      },
    },
    config = function(_, opts)
      require('tokyonight').setup(opts)
      if vim.startswith(active_theme, 'tokyonight') then vim.cmd.colorscheme(active_theme) end
    end,
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    opts = {
      styles = {
        comments = {},
      },
    },
    config = function(_, opts)
      require('catppuccin').setup(opts)
      if active_theme == 'catppuccin' then vim.cmd.colorscheme(active_theme) end
    end,
  },
  {
    'akinsho/bufferline.nvim',
    optional = true,
    opts = function(_, opts)
      if (vim.g.colors_name or ''):find 'catppuccin' then
        opts.highlights = require('catppuccin.special.bufferline').get_theme()
      end
    end,
  },
}
