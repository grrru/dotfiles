local in_herdr = vim.env.HERDR_ENV == "1"

-- Inside Herdr, aim at the agent in Neovim's own tab when there is exactly one, so a
-- send needs no picker. Elsewhere, or with several agents in the tab, sidekick asks.
---@return sidekick.cli.Filter
local function tab_filter()
  local Herdr = require("config.sidekick_herdr")
  local session = Herdr.enabled() and Herdr.tab_session() or nil
  return session and { session = session } or {}
end

local function send(msg)
  return function()
    require("sidekick.cli").send({ msg = msg, filter = tab_filter() })
  end
end

return {

  {
    "folke/sidekick.nvim",
    opts = {
      nes = { enabled = false },
      cli = {
        mux = {
          enabled = true,
          backend = in_herdr and "herdr" or "tmux",
          -- herdr only: new sessions open in a split taking 32% of the Neovim pane
          split = { vertical = true, size = 0.32 },
        },
      },
    },
    config = function(_, opts)
      if in_herdr then
        require("sidekick.cli.session").register("herdr", require("config.sidekick_herdr"))
      end
      require("sidekick").setup(opts)

      -- The session picker only shows the multiplexer session name and the cwd, so
      -- several claude panes started in the same directory are indistinguishable. Their
      -- pane titles are not: claude keeps a summary of what it is doing in there.
      -- Herdr sessions carry that title already; tmux panes are looked up here.
      local Select = require("sidekick.cli.ui.select")
      local format = Select.format
      local cache = { at = 0, panes = {} }

      local function pane_labels()
        if vim.uv.now() - cache.at < 1000 then
          return cache.panes
        end
        cache = { at = vim.uv.now(), panes = {} }
        local out = vim
          .system({ "tmux", "list-panes", "-a", "-F", "#{pane_id} #{window_index}.#{pane_index} #{pane_title}" })
          :wait()
        for line in vim.gsplit(out.stdout or "", "\n", { trimempty = true }) do
          local pane, label = line:match("^(%%%d+) (.*)$")
          if pane then
            cache.panes[pane] = label
          end
        end
        return cache.panes
      end

      Select.format = function(state, picker)
        local ret = format(state, picker)
        local session = state.session
        local pane = session and session.tmux_pane_id
        local label = session and session.herdr_title or pane and pane_labels()[pane]
        if label then
          ret[#ret + 1] = { " " }
          ret[#ret + 1] = { vim.fn.strcharpart(label, 0, 60), "Comment" }
        end
        return ret
      end

      -- ctx() takes the most recently focused window from *every* tab, then calls
      -- getcwd(win), which only searches the current tab (E5002). A window WinEnter
      -- never fired for (the startup window, session-restored tabs) has no
      -- timestamp, so a window in another tab wins. Stamp the current one first.
      local Context = require("sidekick.cli.context")
      local ctx = Context.ctx
      Context.ctx = function()
        local win = vim.api.nvim_get_current_win()
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "sidekick_terminal" then
          vim.w[win].sidekick_visit = vim.uv.hrtime()
        end
        return ctx()
      end

      -- @file references are made relative to the cwd with no option to turn that
      -- off. relpath() fails for a base that is not an ancestor, which leaves the
      -- name absolute, so hand it a cwd that never is one.
      local Loc = require("sidekick.cli.context.location")
      local get = Loc.get
      Loc.get = function(loc, o)
        return get(vim.tbl_extend("force", loc, { cwd = "/nonexistent" }), o)
      end
    end,
    keys = {
      {
        "<leader>a",
        "",
        desc = "+ai",
        mode = { "n", "v" },
      },
      {
        "<leader>aa",
        function()
          if not in_herdr then
            require("sidekick.cli").toggle()
            return
          end
          -- Herdr agents live in their own pane, so jump to it, starting one if needed
          require("sidekick.cli.state").with(function(state)
            if state.session.backend == "herdr" then
              state.session:focus()
            end
          end, { attach = true, filter = tab_filter() })
        end,
        desc = "Sidekick Toggle CLI",
      },
      {
        "<leader>as",
        function()
          require("sidekick.cli").select()
        end,
        desc = "Select CLI",
      },
      {
        "<leader>ad",
        function()
          require("sidekick.cli").close()
        end,
        desc = "Detach a CLI Session",
      },
      {
        "<leader>at",
        send("{this}"),
        desc = "Send This",
        mode = { "n", "x" },
      },
      {
        "<leader>al",
        send("{line}"),
        desc = "Send Current Line",
      },
      {
        "<leader>af",
        send("{file}"),
        desc = "Send File",
      },
      {
        "<leader>av",
        send("{selection}"),
        desc = "Send Visual Selection",
        mode = { "x" },
      },
    },
  },
}
