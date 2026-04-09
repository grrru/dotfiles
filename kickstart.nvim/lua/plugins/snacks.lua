return {
  {
    'folke/snacks.nvim',
    keys = {
      {
        '<leader>e',
        function() Snacks.explorer() end,
        desc = 'Open file [E]xplorer',
      },
    },
    opts = {
      picker = { enabled = true },
      explorer = {
        enabled = true,
        replace_netrw = true,
      },
    },
  },
}
