return {
  {
    'folke/sidekick.nvim',
    keys = {
      {
        '<c-.>',
        function() require('sidekick.cli').toggle() end,
        desc = 'Sidekick Toggle',
        mode = { 'n', 't', 'i', 'x' },
      },
      {
        '<leader>aa',
        function() require('sidekick.cli').toggle() end,
        desc = 'Sidekick Toggle CLI',
      },
      {
        '<leader>as',
        function() require('sidekick.cli').select() end,
        desc = 'Sidekick Select CLI',
      },
      {
        '<leader>ad',
        function() require('sidekick.cli').close() end,
        desc = 'Sidekick Detach CLI Session',
      },
      {
        '<leader>at',
        function() require('sidekick.cli').send { msg = '{this}' } end,
        mode = { 'n', 'x' },
        desc = 'Sidekick Send This',
      },
      {
        '<leader>af',
        function() require('sidekick.cli').send { msg = '{file}' } end,
        desc = 'Sidekick Send File',
      },
      {
        '<leader>av',
        function() require('sidekick.cli').send { msg = '{selection}' } end,
        mode = { 'x' },
        desc = 'Sidekick Send Visual Selection',
      },
      {
        '<leader>ap',
        function() require('sidekick.cli').prompt() end,
        mode = { 'n', 'x' },
        desc = 'Sidekick Select Prompt',
      },
    },
    opts = {
      nes = { enabled = false },
      cli = {
        mux = {
          enabled = true,
          backend = 'tmux',
        },
      },
    },
  },
}
