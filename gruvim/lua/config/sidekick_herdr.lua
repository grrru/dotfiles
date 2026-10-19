-- sidekick.nvim session backend for Herdr (https://herdr.dev).
-- Agents running in Herdr panes become sidekick sessions, text is typed into their pane
-- through the herdr CLI, and new sessions open in a Herdr split next to Neovim.
-- plugins/ai.lua registers it only when Neovim runs inside a Herdr pane (HERDR_ENV=1).
local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Herdr: sidekick.cli.Session
---@field herdr_pane_id string
---@field herdr_tab_id? string
---@field herdr_title? string
local M = {}
M.__index = M

---@param args string[]
---@param opts? {notify?:boolean}
---@return table? result the `result` field of the JSON response
local function herdr(args, opts)
  local cmd = { vim.env.HERDR_BIN_PATH or "herdr" }
  vim.list_extend(cmd, args)
  local _, out = Util.exec(cmd, { notify = opts and opts.notify or false })
  local ok, res = pcall(vim.json.decode, out or "")
  return ok and type(res) == "table" and res.result or nil
end

function M.enabled()
  return vim.env.HERDR_ENV == "1" and vim.env.HERDR_PANE_ID ~= nil
end

---@return sidekick.cli.session.State[]
function M.sessions()
  local res = herdr({ "agent", "list" })
  if not res then
    return {}
  end
  local spaces = {} ---@type table<string,string>
  for _, ws in ipairs((herdr({ "workspace", "list" }) or {}).workspaces or {}) do
    spaces[ws.workspace_id] = ws.label
  end
  local tools = Config.tools()
  local ret = {} ---@type sidekick.cli.session.State[]
  for _, agent in ipairs(res.agents or {}) do
    local tool = tools[agent.agent]
    if tool and agent.pane_id ~= vim.env.HERDR_PANE_ID then
      ret[#ret + 1] = {
        id = "herdr " .. agent.pane_id,
        cwd = agent.foreground_cwd or agent.cwd,
        tool = tool,
        mux_session = spaces[agent.workspace_id] or agent.workspace_id,
        herdr_pane_id = agent.pane_id,
        herdr_tab_id = agent.tab_id,
        herdr_title = agent.terminal_title_stripped,
      }
    end
  end
  return ret
end

--- Id of the agent session in Neovim's own Herdr tab, when there is exactly one.
---@return string?
function M.tab_session()
  local pane = herdr({ "pane", "get", vim.env.HERDR_PANE_ID })
  local tab = pane and pane.pane and pane.pane.tab_id
  local ids = {} ---@type string[]
  for _, s in ipairs(tab and M.sessions() or {}) do
    if s.herdr_tab_id == tab then
      ids[#ids + 1] = s.id
    end
  end
  return #ids == 1 and ids[1] or nil
end

function M:init()
  -- Herdr panes live outside Neovim, so these sessions never open in a Neovim terminal.
  self.external = true
  self.priority = 10
end

---@return sidekick.cli.terminal.Cmd?
function M:start()
  local split = Config.cli.mux.split
  local args = { "pane", "split", "--current", "--direction", split.vertical and "right" or "down" }
  if split.size <= 1 then
    -- herdr's ratio is the share kept by the pane being split
    vim.list_extend(args, { "--ratio", tostring(1 - split.size) })
  end
  vim.list_extend(args, { "--cwd", self.cwd, "--no-focus" })
  local unset = {} ---@type string[]
  for key, value in pairs(self.tool.env or {}) do
    if value == false then
      vim.list_extend(unset, { "-u", key })
    else
      vim.list_extend(args, { "--env", ("%s=%s"):format(key, tostring(value)) })
    end
  end

  local res = herdr(args, { notify = true })
  local pane = res and res.pane and res.pane.pane_id
  if not pane then
    return
  end
  local cmd = #unset > 0 and vim.list_extend({ "env" }, unset) or {}
  vim.list_extend(cmd, self.tool.cmd)
  herdr({ "pane", "run", pane, table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " ") }, { notify = true })

  self.herdr_pane_id = pane
  self.id = "herdr " .. pane
  self.started = true
  Util.info(("Started **%s** in a Herdr split"):format(self.tool.name))

  -- Text typed before the agent is up would land in the shell, so wait until Herdr detects
  -- the agent and it settles.
  vim.wait(10000, function()
    return self:is_running()
  end, 200)
  herdr({ "agent", "wait", pane, "--timeout", "15000" })
end

function M:is_running()
  return self.herdr_pane_id ~= nil and herdr({ "agent", "get", self.herdr_pane_id }) ~= nil
end

---@param text string
function M:send(text)
  -- send-text takes its last argument verbatim, even when it starts with "-"
  local function send()
    herdr({ "pane", "send-text", self.herdr_pane_id, text }, { notify = true })
  end
  if self.tool.mux_focus then
    -- focus-in event first; some TUI apps ignore input while unfocused
    herdr({ "pane", "send-text", self.herdr_pane_id, "\27[I" })
    vim.defer_fn(send, 50)
  else
    send()
  end
end

function M:submit()
  herdr({ "pane", "send-keys", self.herdr_pane_id, "enter" }, { notify = true })
end

function M:focus()
  herdr({ "agent", "focus", self.herdr_pane_id }, { notify = true })
end

return M
