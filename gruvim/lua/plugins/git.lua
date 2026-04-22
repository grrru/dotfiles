return {

  -- Gitsigns
  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    opts = {
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc, silent = true })
        end

        -- Navigation
        map("n", "]c", function()
          gs.nav_hunk("next")
        end, "Next Hunk")
        map("n", "[c", function()
          gs.nav_hunk("prev")
        end, "Prev Hunk")
        map("n", "]C", function()
          gs.nav_hunk("last")
        end, "Last Hunk")
        map("n", "[C", function()
          gs.nav_hunk("first")
        end, "First Hunk")

        -- Actions
        map({ "n", "x" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
        map({ "n", "x" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
        map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
        map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo Stage Hunk")
        map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview Hunk Inline")
        map("n", "<leader>ghb", function()
          gs.blame_line({ full = true })
        end, "Blame Line")
        map("n", "<leader>ghB", function()
          gs.blame()
        end, "Blame Buffer")
        map("n", "<leader>ghd", gs.diffthis, "Diff This")
        map("n", "<leader>ghD", function()
          gs.diffthis("~")
        end, "Diff This ~")

        -- Text object
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")

        -- Toggle
        map("n", "<leader>uG", function()
          gs.toggle_signs()
          vim.notify(
            "Git Signs: " .. (require("gitsigns.config").config.signcolumn and "ON" or "OFF"),
            vim.log.levels.INFO
          )
        end, "Toggle Git Signs")
      end,
    },
  },

  -- Codediff
  {
    "grrru/codediff.nvim",
    cmd = { "CodeDiff" },
    keys = {
      { "<leader>gv", "<cmd>CodeDiff<cr>", desc = "CodeDiff Explorer" },
      { "<leader>gV", "<cmd>CodeDiff history<cr>", desc = "CodeDiff History" },
      { "<leader>gm", "<cmd>CodeDiff main<cr>", desc = "CodeDiff main branch" },
      { "<leader>gM", "<cmd>CodeDiff master<cr>", desc = "CodeDiff master branch" },
    },
    opts = {
      diff = {
        layout = "side-by-side", -- side-by-side, inline
      },
      explorer = {
        width = 30,
        view_mode = "tree",
        focus_on_select = true,
      },
    },
  },
}
