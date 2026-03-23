return {
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      mode = 'cursor',
      max_lines = 2,
      trim_scope = 'inner',
    },
    config = function(_, opts)
      require('treesitter-context').setup(opts)
      vim.api.nvim_set_hl(0, 'TreesitterContextBottom', { underline = false })
      vim.api.nvim_set_hl(0, 'TreesitterContextLineNumberBottom', { underline = false })
    end,
  },
  {
    'Bekaboo/dropbar.nvim',
    dependencies = {
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
      },
    },
    config = function()
      local dropbar_api = require 'dropbar.api'
      vim.keymap.set('n', '<Leader>;', dropbar_api.pick, { desc = 'Pick symbols in winbar' })
      vim.keymap.set('n', '[;', dropbar_api.goto_context_start, { desc = 'Go to start of current context' })
      vim.keymap.set('n', '];', dropbar_api.select_next_context, { desc = 'Select next context' })
    end,
  },
  {
    'folke/zen-mode.nvim',
    opts = {
      plugins = {
        tmux = { enabled = true },
      },
    },
  },
}
