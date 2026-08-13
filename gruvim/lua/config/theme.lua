-- Light/dark switching driven by scripts/toggle-theme.
--
-- The mode lives in ~/.theme_mode; which colorscheme each mode uses is
-- machine-local and read from the dotfiles root's git-ignored theme.conf (see
-- theme.conf.example there for the lookup order). Colorschemes not shipped by
-- this repo can be added through git-ignored specs in lua/local/plugins/.
--
-- Applying a colorscheme fires `User ThemeChanged` so plugins that bake theme
-- colors into their setup (bufferline) can refresh themselves.

local M = {}

local MODE_FILE = vim.fn.expand("~/.theme_mode")

local DEFAULTS = {
  NVIM_LIGHT_COLORSCHEME = "catppuccin-latte",
  NVIM_DARK_COLORSCHEME = "nightfox",
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

local function colorscheme_for(mode)
  local conf = read_conf()
  if mode == "light" then
    return conf.NVIM_LIGHT_COLORSCHEME
  end
  return conf.NVIM_DARK_COLORSCHEME
end

local current_mode

local function apply(mode)
  mode = mode == "light" and "light" or "dark"
  vim.o.background = mode

  local name = colorscheme_for(mode)
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
