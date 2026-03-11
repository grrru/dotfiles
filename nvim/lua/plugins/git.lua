return {
  {
    "esmuellert/codediff.nvim",
    cmd = { "CodeDiff" },
    keys = {
      { "<leader>gv", "<cmd>CodeDiff<cr>", desc = "Git Diff Explorer" },
      { "<leader>gV", "<cmd>CodeDiff history<cr>", desc = "Git Diff History" },
    },
    opts = {
      diff = {
        layout = "side-by-side",
      },
    },
  },
}
