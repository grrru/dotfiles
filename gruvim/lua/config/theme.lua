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
-- With CLAUDE_LIVE_THEME=1 in theme.conf, claude sessions running in terminal
-- buffers are switched too -- toggle-theme only rewrites settings.json, which
-- Claude Code reads at startup and never again. toggle-theme does the same
-- for the claude sessions running directly in a tmux pane.

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

-- Channels of the terminal buffers that have a claude process under them.
-- toggle-theme rewrites ~/.claude/settings.json, but Claude Code only reads
-- that at startup, so already-running sessions have to be driven through
-- their own picker. Claude is usually a child of the terminal's shell rather
-- than the job itself, so walk the process tree up to each terminal job.
local function claude_buffers()
  local job_buf = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "terminal" then
      local pid = vim.b[buf].terminal_job_pid
      local channel = vim.bo[buf].channel
      if pid and channel and channel > 0 then
        job_buf[tonumber(pid)] = { buf = buf, channel = channel }
      end
    end
  end

  if vim.tbl_isempty(job_buf) then
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

  local found, seen = {}, {}
  for pid, comm in pairs(name) do
    if comm == "claude" then
      local cur, hops = pid, 0
      while cur and hops < 10 do
        local target = job_buf[cur]
        if target then
          if not seen[target.channel] then
            seen[target.channel] = true
            found[#found + 1] = target
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

local function claude_editor_mode()
  local dir = vim.env.CLAUDE_CONFIG_DIR
  if not dir or dir == "" then
    dir = vim.fn.expand("~/.claude")
  end

  local ok, lines = pcall(vim.fn.readfile, dir .. "/settings.json")
  if not ok then
    return ""
  end

  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(decoded) ~= "table" then
    return ""
  end

  return decoded.editorMode or ""
end

-- Whatever sits after the last prompt marker on screen. The marker is not
-- anchored to the start of the line: depending on the version the input box
-- draws a border or an indent in front of it.
local function prompt_text(lines)
  for i = #lines, 1, -1 do
    local rest = lines[i]:match(".*❯%s*(.*)$")
    if rest then
      return vim.trim(rest)
    end
  end
  return nil
end

-- Types "/theme" plus the picker's digit into every running claude session,
-- putting back whatever was in the prompt. toggle-theme leaves the digit empty
-- unless CLAUDE_LIVE_THEME is on.
local function switch_claude_theme(key)
  if not key or key == "" then
    return
  end

  local editor_mode = claude_editor_mode()

  for _, target in ipairs(claude_buffers()) do
    -- The bottom of the terminal screen: the prompt, its footer, and any open
    -- dialog.
    local lines = vim.api.nvim_buf_get_lines(target.buf, -9, -1, false)
    local screen = table.concat(lines, "\n")

    -- Typing into a busy session or an open dialog is not just lost -- a digit
    -- answers a permission prompt. Only type at an idle prompt.
    local blocked = screen:find("esc to interrupt", 1, true)
      or screen:find("to confirm", 1, true)
      or screen:find("❯ 1.", 1, true)

    if not blocked then
      local send = function(keys)
        pcall(vim.fn.chansend, target.channel, keys)
      end

      -- A prompt sitting in vim normal mode reads "/theme" as normal-mode
      -- commands instead of text, so the picker never opens. `A` returns to
      -- insert at the end of the line; in insert mode it would type a literal.
      if editor_mode == "vim" and not screen:find("-- INSERT --", 1, true) then
        send("A")
      end

      local before = prompt_text(lines)

      -- C-u kills back to the cursor and C-k forward from it, so the pair
      -- clears a line wherever the cursor sits. One pair per line,
      -- overshooting is free, and the kills accumulate into a single C-y.
      send(("\21\11"):rep(8))

      -- Only restore when those kills actually took something. Reading the
      -- screen again rather than trusting the first read keeps this working
      -- whatever the input box looks like: an empty prompt is unchanged by the
      -- kills, and C-y would then paste back a draft from an earlier run.
      vim.defer_fn(function()
        local after = prompt_text(vim.api.nvim_buf_get_lines(target.buf, -9, -1, false))
        send("/theme\r")

        -- The picker needs a frame to open before it accepts the digit.
        vim.defer_fn(function()
          send(key)
          if before ~= after then
            vim.defer_fn(function()
              send("\25")
            end, 400)
          end
        end, 400)
      end, 300)
    end
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

  switch_claude_theme(state.CLAUDE_LIVE_KEY)
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
    -- write), and every reload types into the claude sessions, so wait for the
    -- burst to end and reload once. Editors rewriting the file can break the
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
