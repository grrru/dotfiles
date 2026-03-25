return {
  {
    "grrru/codediff.nvim",
    cmd = { "CodeDiff" },
    keys = {
      { "<leader>gv", "<cmd>CodeDiff<cr>", desc = "Git Diff Explorer" },
      { "<leader>gV", "<cmd>CodeDiff history<cr>", desc = "Git Diff History" },
      { "<leader>gm", "<cmd>CodeDiff main<cr>", desc = "Git Diff main branch" },
    },
    opts = {
      diff = {
        layout = "inline",
      },
      explorer = {
        width = 30,
        view_mode = "tree",
        focus_on_select = true,
      },
    },
  },
}
