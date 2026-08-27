-- Review mode: change the gitsigns diff base to an arbitrary revision, so the
-- commits after it show up as ordinary working-tree changes (inline signs,
-- ]h/[h, preview_hunk) without a `git reset`. The picked revision plays the
-- role of the reset target: base HEAD~2 == `git reset HEAD~2`.
-- `vim.g.gitsigns_review_base` is what lualine shows.
-- Quickfix jumps skip any window whose buffer has a 'buftype' (the dashboard is
-- "nofile"), so from the dashboard every file opens in a new split instead of
-- reusing the window. Put an empty normal buffer there instead.
local function leave_dashboard()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
      vim.api.nvim_win_call(win, function()
        vim.cmd.enew()
        -- Keep it out of the bufferline and let it go away once the first
        -- quickfix entry takes over the window. 'buftype' stays empty, which is
        -- what makes the window a usable jump target in the first place.
        vim.bo.buflisted = false
        vim.bo.bufhidden = "wipe"
      end)
    end
  end
end

-- Marks the quickfix list as ours, so review mode only closes a window it put
-- there and leaves an unrelated list (grep results, diagnostics) alone.
local QF_TITLE = "Changed Files"

-- setqflist() emits one entry per hunk and has no option to group them
-- (Gitsigns.SetqflistOpts is only use_location_list/nr/open), so collapse the
-- list ourselves: one entry per file, pointing at its first hunk. ]h/[h still
-- walk the hunks once the file is open.
local function collapse_to_files()
  local items = {} --- @type table[]
  local seen = {} --- @type table<integer, integer> bufnr -> index into items
  for _, item in ipairs(vim.fn.getqflist()) do
    local idx = seen[item.bufnr]
    if idx then
      items[idx].hunks = items[idx].hunks + 1
    else
      seen[item.bufnr] = #items + 1
      items[#items + 1] = { bufnr = item.bufnr, lnum = item.lnum, hunks = 1 }
    end
  end
  for _, item in ipairs(items) do
    item.text = ("%d hunk%s"):format(item.hunks, item.hunks > 1 and "s" or "")
    item.hunks = nil
  end
  vim.fn.setqflist({}, "r", { items = items, title = QF_TITLE })
end

-- Tear down what fill_qflist() put up. gitsigns opens the list with `copen`
-- (the `trouble` branch of its setqflist needs config.trouble, which is off),
-- so `cclose` is the matching undo. Scheduled because change_base() resumes its
-- callback wherever the async task landed, and `:cclose` in a fast event
-- context is an E5560.
local function close_qflist()
  vim.schedule(function()
    if vim.fn.getqflist({ title = 0 }).title == QF_TITLE then
      vim.cmd.cclose()
    end
  end)
end

local function fill_qflist()
  -- Hunks of every changed file vs. the base, across the whole repo. Only swap
  -- the dashboard out once the list is up: a picker restores the buffer of the
  -- window it was opened from as it closes, which would undo an earlier swap.
  require("gitsigns").setqflist("all", {}, function()
    vim.schedule(function()
      collapse_to_files()
      leave_dashboard()
    end)
  end)
end

local function set_review_base(base)
  local gs = require("gitsigns")
  gs.change_base(base, true, function(err)
    if err then
      vim.notify("gitsigns: " .. err, vim.log.levels.ERROR)
      return
    end
    vim.g.gitsigns_review_base = base
    if base then
      fill_qflist()
    else
      close_qflist()
      vim.notify("Review mode off (base: index)")
    end
  end)
end

return {

  -- Gitsigns
  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>gR",
        function()
          set_review_base(nil)
        end,
        desc = "Review Mode Off",
      },
      {
        "<leader>gr",
        function()
          Snacks.picker.git_log({
            confirm = function(picker, item)
              picker:close()
              local sha = item and (item.commit or item.text:match("%x%x%x%x%x%x%x+"))
              if sha then
                set_review_base(sha)
              end
            end,
          })
        end,
        desc = "Review Mode (pick base commit)",
      },
      {
        "<leader>gq",
        function()
          fill_qflist()
        end,
        desc = "Changed Files to Quickfix",
      },
    },
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
        map("n", "<leader>ghp", gs.preview_hunk, "Preview Hunk")
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
