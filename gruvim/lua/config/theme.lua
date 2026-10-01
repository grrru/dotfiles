-- Light/dark switching driven by scripts/toggle-theme.
--
-- toggle-theme is the only reader of the theme config (theme.defaults.conf and
-- the machine-local theme.conf in the dotfiles root). It resolves them into
-- ~/.theme_mode, which Neovim watches and applies as is. Colorschemes not
-- shipped by this repo can be added through git-ignored specs in
-- lua/local/plugins/.
--
-- Applying a colorscheme fires `User ThemeChanged` so plugins that bake theme
-- colors into their setup (bufferline) can refresh themselves.
--
-- Terminal buffers running claude or a tmux client (sidekick attaches its
-- sessions that way) are told about the change too, so Claude Code's `auto`
-- theme follows it in sessions that are already running.

local M = {}

local STATE_FILE = vim.fn.expand("~/.theme_mode")

-- For when the state file is missing or names a colorscheme this machine
-- cannot load.
local FALLBACK = {
  light = "catppuccin-latte",
  dark = "catppuccin-frappe",
}

-- Parses the KEY="value" lines toggle-theme writes. Older versions wrote only
-- the bare mode word.
local function read_state()
  local state = {}
  if vim.fn.filereadable(STATE_FILE) ~= 1 then
    return state
  end

  for _, line in ipairs(vim.fn.readfile(STATE_FILE)) do
    local key, value = line:match('^([%w_]+)="(.*)"$')
    if key then
      state[key] = value
    elseif line == "light" or line == "dark" then
      state.MODE = line
    end
  end

  return state
end

-- Channels of the terminal buffers that take a theme report (DEC mode 2031):
-- a tmux client, which then asks this terminal for its colors again, or a
-- claude, which asks itself. Neovim answers those queries from 'background'
-- but never sends the report on its own. Both usually run below the buffer's
-- job (a shell) rather than as the job, so walk the process tree up to each
-- job. Any other job would get the report as typed input.
local function theme_report_channels()
  local job_channel = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "terminal" then
      local pid = vim.b[buf].terminal_job_pid
      local channel = vim.bo[buf].channel
      if pid and channel and channel > 0 then
        job_channel[tonumber(pid)] = channel
      end
    end
  end

  if vim.tbl_isempty(job_channel) then
    return {}
  end

  local parent, name = {}, {}
  for _, line in ipairs(vim.fn.systemlist("ps -Ao pid=,ppid=,comm=")) do
    local pid, ppid, comm = line:match("^%s*(%d+)%s+(%d+)%s+(.+)$")
    if pid then
      parent[tonumber(pid)] = tonumber(ppid)
      name[tonumber(pid)] = vim.fn.fnamemodify(comm, ":t")
    end
  end

  -- tmux renames its processes to "tmux: client" / "tmux: server" on Linux.
  local found, seen = {}, {}
  for pid, comm in pairs(name) do
    if comm == "claude" or comm == "tmux" or vim.startswith(comm, "tmux: ") then
      local cur, hops = pid, 0
      while cur and hops < 10 do
        local channel = job_channel[cur]
        if channel then
          if not seen[channel] then
            seen[channel] = true
            found[#found + 1] = channel
          end
          break
        end
        cur = parent[cur]
        hops = hops + 1
      end
    end
  end

  return found
end

local function report_theme(mode)
  local report = mode == "light" and "\27[?997;2n" or "\27[?997;1n"
  for _, channel in ipairs(theme_report_channels()) do
    pcall(vim.fn.chansend, channel, report)
  end
end

local current_mode

local function apply(state)
  local mode = state.MODE == "light" and "light" or "dark"

  -- Clear first: changing 'background' reloads the old scheme and unsets
  -- g:colors_name, so catppuccin skips its own `hi clear` and groups it does
  -- not define (NvimTreeNormal) keep the old colors.
  vim.cmd("highlight clear")
  vim.o.background = mode

  local name = state.NVIM_COLORSCHEME
  if not name or name == "" then
    name = FALLBACK[mode]
  end

  local ok = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify(
      ("theme: colorscheme %q is not available, falling back to %q"):format(name, FALLBACK[mode]),
      vim.log.levels.WARN
    )
    pcall(vim.cmd.colorscheme, FALLBACK[mode])
  end

  current_mode = mode
  vim.api.nvim_exec_autocmds("User", { pattern = "ThemeChanged", modeline = false })

  report_theme(mode)
end

function M.reload()
  apply(read_state())
end

function M.mode()
  return current_mode
end

function M.setup()
  M.reload()

  local watcher = vim.uv.new_fs_event()
  local settle = vim.uv.new_timer()
  if watcher and settle then
    -- A single rewrite arrives as several events (the truncate, then the
    -- write), and every reload sends theme reports, so wait for the burst to
    -- end and reload once. Editors rewriting the file can break the
    -- watch; re-arm after every reload.
    local function watch()
      watcher:stop()
      watcher:start(STATE_FILE, {}, function()
        settle:stop()
        settle:start(
          100,
          0,
          vim.schedule_wrap(function()
            M.reload()
            watch()
          end)
        )
      end)
    end
    watch()
  end
end

return M
