local function origin_main_or_master()
  vim.fn.system({ "git", "show-ref", "--verify", "--quiet", "refs/remotes/origin/main" })
  return vim.v.shell_error == 0 and "origin/main" or "origin/master"
end

return {

  -- Gitsigns
  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    opts = {
      on_attach = function(bufnr)
        local gs = require("gitsigns")

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc, silent = true })
        end

        -- Navigation
        map("n", "]h", function()
          gs.nav_hunk("next")
        end, "Next Hunk")
        map("n", "[h", function()
          gs.nav_hunk("prev")
        end, "Prev Hunk")
        map("n", "]H", function()
          gs.nav_hunk("last")
        end, "Last Hunk")
        map("n", "[H", function()
          gs.nav_hunk("first")
        end, "First Hunk")

        -- Actions
        map("n", "<leader>ghs", gs.stage_hunk, "Stage Hunk")
        map("x", "<leader>ghs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage Hunk")
        map("n", "<leader>ghr", gs.reset_hunk, "Reset Hunk")
        map("x", "<leader>ghr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset Hunk")
        map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
        map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
        map("n", "<leader>ghb", function()
          gs.blame_line({ full = true })
        end, "Blame Line")
        map("n", "<leader>ghB", gs.blame, "Blame Buffer")
      end,
    },
  },

  -- Diffview
  {
    "dlyongemallo/diffview-plus.nvim",
    version = "*",
    cmd = {
      "DiffviewOpen",
      "DiffviewFileHistory",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
    },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
      { "<leader>gV", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview File History" },
      {
        "<leader>gm",
        function()
          vim.cmd.DiffviewOpen(origin_main_or_master() .. "...HEAD --imply-local")
        end,
        desc = "Diffview main/master",
      },
    },
    opts = function()
      local actions = require("diffview.actions")

      return {
        view = {
          default = { layout = "diff2_horizontal" },
          merge_tool = { layout = "diff3_horizontal" },
        },
        file_panel = {
          listing_style = "tree",
          win_config = { position = "left", width = 30 },
        },
        keymaps = {
          view = {
            { "n", "<leader>e", actions.toggle_files, { desc = "Toggle File Panel" } },
          },
          file_panel = {
            { "n", "<leader>e", actions.toggle_files, { desc = "Toggle File Panel" } },
          },
          file_history_panel = {
            { "n", "<leader>e", actions.toggle_files, { desc = "Toggle File Panel" } },
          },
        },
      }
    end,
  },
}
