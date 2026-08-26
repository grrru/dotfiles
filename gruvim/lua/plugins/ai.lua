return {

  {
    "folke/sidekick.nvim",
    opts = {
      nes = { enabled = false },
      cli = {
        mux = {
          enabled = true,
          backend = "tmux",
        },
      },
    },
    config = function(_, opts)
      require("sidekick").setup(opts)

      -- The session picker only shows the tmux session name and the cwd, so several
      -- claude panes started in the same directory are indistinguishable. Their pane
      -- titles are not: claude keeps a summary of what it is doing in there.
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
        local pane = state.session and state.session.tmux_pane_id
        local label = pane and pane_labels()[pane]
        if label then
          ret[#ret + 1] = { " " }
          ret[#ret + 1] = { vim.fn.strcharpart(label, 0, 60), "Comment" }
        end
        return ret
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
          require("sidekick.cli").toggle()
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
        function()
          require("sidekick.cli").send({ msg = "{this}" })
        end,
        desc = "Send This",
        mode = { "n", "x" },
      },
      {
        "<leader>al",
        function()
          require("sidekick.cli").send({ msg = "{line}" })
        end,
        desc = "Send Current Line",
      },
      {
        "<leader>af",
        function()
          require("sidekick.cli").send({ msg = "{file}" })
        end,
        desc = "Send File",
      },
      {
        "<leader>av",
        function()
          require("sidekick.cli").send({ msg = "{selection}" })
        end,
        desc = "Send Visual Selection",
        mode = { "x" },
      },
    },
  },
}
