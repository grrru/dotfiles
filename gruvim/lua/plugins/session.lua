-- Each tab :tcd's into its own root and scope.nvim keeps a buffer list per
-- tab by unlisting the other tabs' buffers. A plain :mksession only records
-- listed buffers, so only the active tab kept its list and on restore those
-- buffers all showed up in the first tab. Remember the buffers per root in a
-- global (sessionoptions has "globals") and, after the session is sourced,
-- give every tab the buffers of the root it was :tcd'd into.
local ROOT_BUFFERS = "ScopeRootBuffers"

-- Directory buffers (nvim-tree hijacks) are left out: they are not something
-- to reopen, and :edit on one on restore opens the tree instead.
local function is_file_buf(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buftype == ""
    and vim.fn.filereadable(vim.api.nvim_buf_get_name(buf)) == 1
end

local function tab_root(tabnr)
  return vim.fn.getcwd(-1, tabnr)
end

local function save_root_buffers()
  local ok, core = pcall(require, "scope.core")
  if not ok then
    return
  end

  -- Read the active tab's listed buffers before any other tab's get listed
  core.revalidate()
  local roots = {}
  local to_list = {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local root = tab_root(i)
    local names = roots[root] or {}
    for _, buf in ipairs(core.cache[tab] or {}) do
      local name = vim.api.nvim_buf_get_name(buf)
      if is_file_buf(buf) and not vim.tbl_contains(names, name) then
        names[#names + 1] = name
        to_list[#to_list + 1] = buf
      end
    end
    roots[root] = names
  end
  -- :mksession only writes :badd for listed buffers
  for _, buf in ipairs(to_list) do
    vim.bo[buf].buflisted = true
  end
  vim.g[ROOT_BUFFERS] = vim.json.encode(roots)
end

local function restore_root_buffers()
  local state = vim.g[ROOT_BUFFERS]
  vim.g[ROOT_BUFFERS] = nil
  local ok, core = pcall(require, "scope.core")
  if not ok or type(state) ~= "string" then
    return
  end

  local roots = vim.json.decode(state)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
      vim.bo[buf].buflisted = false
    end
  end

  core.cache = {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local ids = {}
    for _, name in ipairs(roots[tab_root(i)] or {}) do
      ids[#ids + 1] = vim.fn.bufadd(name)
    end
    core.cache[tab] = ids
  end
  core.on_tab_enter()
end

return {

  -- Persistence (세션 저장/복원)
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    config = function(_, opts)
      local persistence = require("persistence")
      local Config = require("persistence.config")
      persistence.setup(opts)

      -- The session file is named after getcwd(), which is the *active tab's*
      -- :tcd. Quitting from the second tab saved the session under that
      -- project, and the dashboard (global cwd) then restored a stale one.
      -- Always key it on the global cwd.
      persistence.current = function(o)
        o = o or {}
        local cwd = vim.fn.getcwd(-1, -1)
        local name = cwd:gsub("[\\/:]+", "%%")
        if Config.options.branch and o.branch ~= false and vim.uv.fs_stat(cwd .. "/.git") then
          local branch = vim.fn.systemlist({ "git", "-C", cwd, "branch", "--show-current" })[1]
          if vim.v.shell_error == 0 and branch and branch ~= "main" and branch ~= "master" then
            name = name .. "%%" .. branch:gsub("[\\/:]+", "%%")
          end
        end
        return Config.options.dir .. name .. ".vim"
      end

      local group = vim.api.nvim_create_augroup("persistence_scope", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "PersistenceSavePre",
        callback = save_root_buffers,
      })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "PersistenceLoadPost",
        callback = restore_root_buffers,
      })
    end,
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").load()
        end,
        desc = "Restore Session",
      },
      {
        "<leader>qS",
        function()
          require("persistence").select()
        end,
        desc = "Select Session",
      },
      {
        "<leader>ql",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore Last Session",
      },
      {
        "<leader>qd",
        function()
          require("persistence").stop()
        end,
        desc = "Don't Save Current Session",
      },
    },
  },
}
