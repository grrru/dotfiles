-- Light/dark switching driven by scripts/toggle-theme.
--
-- The mode lives in ~/.theme_mode; which colorscheme each mode uses is
-- machine-local and read from the dotfiles root's git-ignored theme.conf (see
-- theme.conf.example there for the lookup order). Colorschemes not shipped by
-- this repo can be added through git-ignored specs in lua/local/plugins/.
--
-- Applying a colorscheme fires `User ThemeChanged` so plugins that bake theme
-- colors into their setup (bufferline) can refresh themselves.
--
-- With CLAUDE_LIVE_THEME=1 in theme.conf, claude sessions running in terminal
-- buffers are switched too -- toggle-theme only rewrites settings.json, which
-- Claude Code reads at startup and never again. toggle-theme does the same
-- for the claude sessions running directly in a tmux pane.

local M = {}

local MODE_FILE = vim.fn.expand("~/.theme_mode")

local DEFAULTS = {
  NVIM_LIGHT_COLORSCHEME = "catppuccin-latte",
  NVIM_DARK_COLORSCHEME = "nightfox",
  CLAUDE_LIGHT_THEME = "light",
  CLAUDE_DARK_THEME = "dark",
  CLAUDE_LIVE_THEME = "0",
}

-- Position of each theme in Claude Code's `/theme` picker. The picker applies
-- a choice as soon as its digit is typed, so switching a running session is
-- "/theme<CR>" followed by one key.
local CLAUDE_THEME_KEY = {
  ["auto"] = "1",
  ["dark"] = "2",
  ["light"] = "3",
  ["dark-daltonized"] = "4",
  ["light-daltonized"] = "5",
  ["dark-ansi"] = "6",
  ["light-ansi"] = "7",
}

-- Fallbacks for when theme.conf names a colorscheme this machine cannot load.
local FALLBACK = {
  light = "catppuccin-latte",
  dark = "catppuccin-frappe",
}

-- The nvim config dir is a symlink into the dotfiles repo (gruvim/), so resolve
-- it to find the repo root that holds theme.conf.
local function dotfiles_root()
  local resolved = vim.fn.resolve(vim.fn.stdpath("config"))
  local root = vim.fn.fnamemodify(resolved, ":h")
  if vim.fn.isdirectory(root .. "/ghostty") == 1 then
    return root
  end
  return vim.fn.expand("~/dotfiles")
end

-- First existing file wins. Keep in sync with the list in scripts/toggle-theme.
local function conf_path()
  local candidates = {}

  local override = vim.env.DOTFILES_THEME_CONF
  if override and override ~= "" then
    table.insert(candidates, vim.fn.expand(override))
  end

  table.insert(candidates, dotfiles_root() .. "/theme.conf")

  local xdg = vim.env.XDG_CONFIG_HOME
  if xdg and xdg ~= "" then
    table.insert(candidates, xdg .. "/dotfiles/theme.conf")
  else
    table.insert(candidates, vim.fn.expand("~/.config/dotfiles/theme.conf"))
  end

  for _, path in ipairs(candidates) do
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end

  return candidates[#candidates]
end

-- Parses the shell-sourceable KEY="value" subset that theme.conf is limited to.
local function read_conf()
  local conf = vim.tbl_extend("force", {}, DEFAULTS)

  local path = conf_path()
  if vim.fn.filereadable(path) ~= 1 then
    return conf
  end

  for _, line in ipairs(vim.fn.readfile(path)) do
    local key, raw = line:match("^%s*([%a_][%w_]*)%s*=%s*(.-)%s*$")
    if key and DEFAULTS[key] then
      local value = raw:match('^"(.-)"') or raw:match("^'(.-)'")
      if not value then
        -- Unquoted: stop at whitespace or a trailing comment.
        value = raw:match("^[^%s#]+") or ""
      end
      if value ~= "" then
        conf[key] = value
      end
    end
  end

  return conf
end

local function colorscheme_for(conf, mode)
  if mode == "light" then
    return conf.NVIM_LIGHT_COLORSCHEME
  end
  return conf.NVIM_DARK_COLORSCHEME
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

-- Types "/theme" plus the picker's digit into every running claude session,
-- putting back whatever was in the prompt. Opt-in through CLAUDE_LIVE_THEME.
local function switch_claude_theme(conf, mode)
  if conf.CLAUDE_LIVE_THEME ~= "1" then
    return
  end

  local theme = mode == "light" and conf.CLAUDE_LIGHT_THEME or conf.CLAUDE_DARK_THEME
  local key = CLAUDE_THEME_KEY[theme]
  if not key then
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

      -- In vim mode the prompt can sit in normal mode, where C-u only kills
      -- back to the cursor. `A` is a no-op keystroke there that returns to
      -- insert at the end of the line; in insert mode it would type a literal.
      if editor_mode == "vim" and not screen:find("-- INSERT --", 1, true) then
        send("A")
      end

      -- C-u kills one line, so a multi-line draft needs several -- and
      -- overshooting is free, because the kills accumulate into one C-y.
      send(("\21"):rep(8))
      send("/theme\r")

      -- Only restore when the prompt actually held something: with an empty
      -- prompt C-u kills nothing and C-y would paste back an older draft.
      local draft
      for i = #lines, 1, -1 do
        local rest = lines[i]:match("^❯%s*(.*)$")
        if rest then
          draft = vim.trim(rest)
          break
        end
      end

      -- The picker needs a frame to open before it accepts the digit.
      vim.defer_fn(function()
        send(key)
        if draft and draft ~= "" then
          vim.defer_fn(function()
            send("\25")
          end, 400)
        end
      end, 400)
    end
  end
end

local current_mode

local function apply(mode)
  mode = mode == "light" and "light" or "dark"
  vim.o.background = mode

  local conf = read_conf()

  local name = colorscheme_for(conf, mode)
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

  switch_claude_theme(conf, mode)
end

local function read_mode()
  if vim.fn.filereadable(MODE_FILE) == 1 then
    local line = vim.fn.readfile(MODE_FILE, "", 1)[1]
    if line and line:lower():find("light", 1, true) then
      return "light"
    end
  end
  return "dark"
end

function M.reload()
  apply(read_mode())
end

function M.mode()
  return current_mode
end

function M.setup()
  M.reload()

  local watcher = vim.uv.new_fs_event()
  if watcher then
    -- Editors rewriting the file can break the watch; re-arm on every event.
    local function watch()
      watcher:stop()
      watcher:start(MODE_FILE, {}, function()
        vim.schedule(function()
          M.reload()
          watch()
        end)
      end)
    end
    watch()
  end
end

return M
