return {
  {
    'esmuellert/codediff.nvim',
    cmd = { 'CodeDiff' },
    keys = {
      { '<leader>gv', '<cmd>CodeDiff<cr>', desc = 'Git Diff Explorer' },
      { '<leader>gV', '<cmd>CodeDiff history<cr>', desc = 'Git Diff History' },
      { '<leader>gm', '<cmd>CodeDiff main<cr>', desc = 'Git Diff Main Branch' },
    },
    opts = {
      diff = {
        layout = 'inline',
      },
      explorer = {
        width = 30,
        view_mode = 'tree',
        focus_on_select = true,
      },
      keymaps = {
        view = {
          next_hunk = ']h',
          prev_hunk = '[h',
        },
      },
    },
  },
}
