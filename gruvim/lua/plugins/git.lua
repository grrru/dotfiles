-- Review mode: change the gitsigns diff base to an arbitrary revision, so the
-- commits after it show up as ordinary working-tree changes (inline signs,
-- ]h/[h, preview_hunk) without a `git reset`. The picked revision plays the
-- role of the reset target: base HEAD~2 == `git reset HEAD~2`. For a whole
-- branch, prefer the merge base with its upstream (<leader>gru) over counting
-- commits back by hand: it is the same range a PR shows.
--
-- Review mode belongs to the tab it was turned on in and covers the buffers of
-- that tab's worktree only. Other repositories, and other worktrees of the same
-- repository, stay diffed against the index. gitsigns has a single global base
-- for every buffer, so that one stays at the index and the review base is set
-- buffer by buffer. `vim.t.gitsigns_review_base` is what lualine shows.

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

-- One entry per file in a `git diff -U0` listing, at its first hunk. ]h/[h
-- walk the rest once the file is open. File headers are only read between
-- `diff --git` and the first `@@`, where a removed line such as "-- a/x" cannot
-- pass for one.
local function diff_to_items(root, lines)
  local items = {} --- @type table[]
  local item, in_header, old_path
  for _, line in ipairs(lines) do
    if vim.startswith(line, "diff --git ") then
      item, in_header, old_path = nil, true, nil
    elseif in_header and vim.startswith(line, "--- a/") then
      -- git ends a header path that has a space in it with a tab
      old_path = (line:sub(7):gsub("\t$", ""))
    elseif in_header and vim.startswith(line, "+++ ") then
      local deleted = line == "+++ /dev/null"
      local path = deleted and old_path or (vim.startswith(line, "+++ b/") and (line:sub(7):gsub("\t$", "")))
      if path then
        item = { filename = root .. "/" .. path, lnum = 1, hunks = 0, deleted = deleted }
        items[#items + 1] = item
      end
    elseif vim.startswith(line, "@@ ") then
      in_header = false
      if item then
        item.hunks = item.hunks + 1
        if item.hunks == 1 then
          -- A pure deletion starts at the line before it, which may be 0
          item.lnum = math.max(tonumber(line:match("^@@ %-%S+ %+(%d+)")) or 1, 1)
        end
      end
    end
  end
  for _, it in ipairs(items) do
    it.text = it.deleted and "deleted" or ("%d hunk%s"):format(it.hunks, it.hunks > 1 and "s" or "")
    it.hunks, it.deleted = nil, nil
  end
  return items
end

-- Files changed in the worktree {root} since {base} (the index when nil). This
-- is `git diff` rather than gitsigns' setqflist("all"), which takes in every
-- repository with an attached buffer and diffs them all against the global base.
local function fill_qflist(root, base)
  local cmd = { "git", "-C", root, "-c", "core.quotePath=false", "diff", "-U0", "--no-color", "--no-ext-diff" }
  vim.list_extend(cmd, { "--src-prefix=a/", "--dst-prefix=b/", "--ignore-submodules" })
  if base then
    cmd[#cmd + 1] = base
  end
  cmd[#cmd + 1] = "--"
  -- Asynchronous so the list goes up after a picker that is closing has put
  -- back the buffer of the window it was opened from; swapping the dashboard
  -- out before that would be undone.
  vim.system(cmd, { text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        vim.notify("git diff: " .. vim.trim(out.stderr or ""), vim.log.levels.ERROR)
        return
      end
      vim.fn.setqflist({}, " ", { items = diff_to_items(root, vim.split(out.stdout, "\n")), title = QF_TITLE })
      vim.cmd.copen()
      leave_dashboard()
    end)
  end)
end

-- Tear down what fill_qflist() put up: it opens the list with `copen`, so
-- `cclose` is the matching undo.
local function close_qflist()
  if vim.fn.getqflist({ title = 0 }).title == QF_TITLE then
    vim.cmd.cclose()
  end
end

-- `git` in the tab's cwd, returning trimmed stdout or nil.
local function git(...)
  local out = vim.system({ "git", ... }, { text = true, cwd = vim.fn.getcwd() }):wait()
  if out.code ~= 0 then
    return nil
  end
  local stdout = vim.trim(out.stdout)
  return stdout ~= "" and stdout or nil
end

-- The branch a PR from here would target. `origin/HEAD` is what the remote
-- calls its default branch; the rest are fallbacks for repos where it was never
-- fetched (`git remote set-head origin -a` creates it).
local function upstream_branch()
  local head = git("symbolic-ref", "--short", "refs/remotes/origin/HEAD")
  if head then
    return head
  end
  for _, ref in ipairs({ "origin/main", "origin/master", "main", "master" }) do
    if git("rev-parse", "--verify", "--quiet", ref) then
      return ref
    end
  end
end

--- @class gruvim.GitReview
--- @field root string Toplevel of the worktree under review.
--- @field base string

-- Reviews by tab handle. A tab reviews one worktree and a worktree is reviewed
-- from one tab. Kept here and not only in vim.t: a tab's variables are gone by
-- the time TabClosed fires, and the closed tab's worktree still has to go back
-- to the index.
local reviews = {} --- @type table<integer, gruvim.GitReview>

-- Buffers mid-attach on a base already chosen for them. on_attach skips its
-- review check for these, which would otherwise turn the attach down again.
local attaching = {} --- @type table<integer, true>

local function review_of(root)
  for _, review in pairs(reviews) do
    if review.root == root then
      return review
    end
  end
end

-- Attach {buf} afresh against {base} (the index when nil). change_base() on a
-- buffer whose update is still running (one just opened, or just brought into
-- view) loses to that update, which caches the old base's text and keeps
-- diffing against it. A fresh attach starts from an empty cache.
local function attach_on(buf, base, callback)
  local gs = require("gitsigns")
  gs.detach(buf)
  attaching[buf] = true
  local ctx = { file = vim.api.nvim_buf_get_name(buf), base = base or ":0" }
  gs.attach({ bufnr = buf, ctx = ctx }, function(err)
    attaching[buf] = nil
    if callback then
      callback(err)
    end
  end)
end

-- Put every loaded buffer gitsigns placed in the worktree {root} on {base},
-- then call {done} with the first error.
local function set_root_base(root, base, done)
  local bufs = {} --- @type integer[]
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local status = vim.api.nvim_buf_is_loaded(buf) and vim.b[buf].gitsigns_status_dict
    if status and status.root == root then
      bufs[#bufs + 1] = buf
    end
  end
  local pending, first_err = #bufs, nil
  local function finish()
    vim.schedule(function()
      done(first_err)
    end)
  end
  if pending == 0 then
    return finish()
  end
  for _, buf in ipairs(bufs) do
    attach_on(buf, base, function(err)
      first_err = first_err or err
      pending = pending - 1
      if pending == 0 then
        finish()
      end
    end)
  end
end

-- Turn review mode on in the current tab with {base}, or off when it is nil.
local function set_review_base(base, label)
  local tab = vim.api.nvim_get_current_tabpage()
  local old = reviews[tab]
  -- Off goes by the worktree the review was turned on for, which a later :tcd
  -- does not change.
  local root = base and git("rev-parse", "--show-toplevel") or (old and old.root)
  if not root then
    vim.notify(base and "Not in a git repository" or "Review mode is not on in this tab", vim.log.levels.WARN)
    return
  end
  for t, review in pairs(reviews) do
    if t ~= tab and review.root == root then
      reviews[t] = nil
      vim.t[t].gitsigns_review_base = nil
    end
  end
  if old and old.root ~= root then
    set_root_base(old.root, nil, function() end)
  end
  reviews[tab] = base and { root = root, base = base } or nil
  vim.t[tab].gitsigns_review_base = base and (label or base) or nil
  set_root_base(root, base, function(err)
    if err then
      vim.notify("gitsigns: " .. err, vim.log.levels.ERROR)
      return
    end
    if base then
      fill_qflist(root, base)
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
    init = function()
      vim.api.nvim_create_autocmd("TabClosed", {
        group = vim.api.nvim_create_augroup("gruvim_git_review", { clear = true }),
        desc = "Put the worktree a closed tab reviewed back on the index",
        callback = function()
          for tab, review in pairs(reviews) do
            if not vim.api.nvim_tabpage_is_valid(tab) then
              reviews[tab] = nil
              set_root_base(review.root, nil, function() end)
            end
          end
        end,
      })
    end,
    keys = {
      {
        "<leader>gro",
        function()
          set_review_base(nil)
        end,
        desc = "Review Mode Off",
      },
      {
        "<leader>grc",
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
        "<leader>gru",
        function()
          local branch = upstream_branch()
          if not branch then
            vim.notify("No upstream branch to compare against", vim.log.levels.ERROR)
            return
          end
          -- What a PR shows: the three-dot diff `branch...HEAD`, which is the
          -- diff against the point the branch forked from. Merging the upstream
          -- back in ("Update branch") moves that point forward, so the review
          -- stays scoped to this branch's own commits instead of picking up
          -- everything the merge brought along -- which is what a hand-picked
          -- HEAD~N base would do.
          local sha = git("merge-base", branch, "HEAD")
          if not sha then
            vim.notify("No merge base with " .. branch, vim.log.levels.ERROR)
            return
          end
          set_review_base(sha, branch .. "...")
        end,
        desc = "Review Mode (branch vs. upstream)",
      },
      {
        "<leader>gq",
        function()
          local review = reviews[vim.api.nvim_get_current_tabpage()]
          local root = review and review.root or git("rev-parse", "--show-toplevel")
          if not root then
            vim.notify("Not in a git repository", vim.log.levels.WARN)
            return
          end
          fill_qflist(root, review and review.base)
        end,
        desc = "Changed Files to Quickfix",
      },
    },
    opts = {
      on_attach = function(bufnr)
        local gs = require("gitsigns")

        -- A buffer opened (from the Changed Files list, say) or re-read while
        -- its worktree is under review attaches on the index like any other:
        -- turn that attach down and attach it again on the review base.
        local status = vim.b[bufnr].gitsigns_status_dict
        local review = not attaching[bufnr] and status and review_of(status.root)
        if review then
          vim.schedule(function()
            if vim.api.nvim_buf_is_loaded(bufnr) then
              attach_on(bufnr, review.base)
            end
          end)
          return false
        end

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
}
