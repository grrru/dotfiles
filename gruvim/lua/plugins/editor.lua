local function nvim_meta_section()
  local version = vim.version()
  return {
    align = "center",
    text = {
      { string.format("NVIM v%d.%d.%d", version.major, version.minor, version.patch), hl = "title" },
      {
        "\n────────────────────────────────────────────",
        hl = "nontext",
      },
      { "\nNvim is open source and freely distributable", hl = "comment" },
      { "\nhttps://neovim.io/#chat", hl = "comment" },
      {
        "\n────────────────────────────────────────────",
        hl = "nontext",
      },
    },
    padding = 1,
  }
end

local function nvim_logo_section()
  return {
    align = "center",
    text = {
      { "│ ", hl = "special" },
      { "╲ ││", hl = "string" },
      { "\n││", hl = "special" },
      { "╲╲││", hl = "string" },
      { "\n││ ", hl = "special" },
      { "╲ │", hl = "string" },
    },
    padding = 1,
  }
end

return {

  -- Snacks (picker, explorer, dashboard, image, scratch, etc.)
  {
    "grrru/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      quickfile = { enabled = true },
      picker = {
        layout = {
          layout = {
            width = 0.9,
            height = 0.9,
          },
        },
        sources = {
          explorer = {
            hidden = true,
            ignored = false,
            layout = { layout = { width = 30 } },
            format = function(item, picker)
              if item.severity and item.severity > vim.diagnostic.severity.ERROR then
                item.severity = nil
              end
              return Snacks.picker.format.file(item, picker)
            end,
          },
          files = {
            hidden = true,
            ignored = true,
          },
        },
      },
      image = {
        enabled = true,
        doc = {
          inline = true,
          float = false,
        },
        formats = { "png", "jpg", "jpeg", "gif", "webp", "pdf", "mp4", "mov", "bmp", "tiff", "ico" },
      },
      dashboard = {
        enabled = true,
        sections = {
          nvim_logo_section(),
          nvim_meta_section(),
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
        preset = {
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            {
              icon = " ",
              key = "c",
              desc = "Config",
              action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
            },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = " ", key = "r", desc = "Restore Session", section = "session" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
      },
      terminal = { enabled = true }, -- TODO: terminal 열 때, 파일 윈도우 스크롤이 올라가는 현상 해결
      notifier = { enabled = true },
      scope = { enabled = true },
      indent = { enabled = true },
      scroll = { enabled = true },
      animate = { enabled = true },
      dim = { enabled = false },
      words = { enabled = true },
      statuscolumn = { enabled = true },
    },
    keys = {
      -- Find
      {
        "<leader><space>",
        function()
          Snacks.picker.files({ root = false })
        end,
        desc = "Find Files (cwd)",
      },
      {
        "<leader>ff",
        function()
          Snacks.picker.files()
        end,
        desc = "Find Files (root)",
      },
      {
        "<leader>fF",
        function()
          Snacks.picker.files({ root = false })
        end,
        desc = "Find Files (cwd)",
      },
      {
        "<leader>fc",
        function()
          Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
        end,
        desc = "Find Config File",
      },
      {
        "<leader>fb",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Buffers",
      },
      -- Explorer
      {
        "<leader>e",
        function()
          Snacks.picker.explorer({ root = false })
        end,
        desc = "Explorer (cwd)",
      },
      {
        "<leader>E",
        function()
          Snacks.picker.explorer()
        end,
        desc = "Explorer (root)",
      },
      -- Grep
      {
        "<leader>sg",
        function()
          Snacks.picker.grep({ root = false })
        end,
        desc = "Grep (cwd)",
      },
      {
        "<leader>sG",
        function()
          Snacks.picker.grep()
        end,
        desc = "Grep (root)",
      },
      {
        "<leader>sw",
        function()
          Snacks.picker.grep_word()
        end,
        desc = "Visual selection or word (root)",
        mode = { "n", "x" },
      },
      {
        "<leader>sb",
        function()
          Snacks.picker.lines()
        end,
        desc = "Buffer Lines",
      },
      {
        "<leader>sB",
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = "Grep Open Buffers",
      },
      -- Search
      {
        "<leader>n",
        function()
          Snacks.picker.notifications()
        end,
        desc = "Notification History",
      },
      {
        '<leader>s"',
        function()
          Snacks.picker.registers()
        end,
        desc = "Registers",
      },
      {
        "<leader>sa",
        function()
          Snacks.picker.autocmds()
        end,
        desc = "Autocmds",
      },
      {
        "<leader>sc",
        function()
          Snacks.picker.command_history()
        end,
        desc = "Command History",
      },
      {
        "<leader>sC",
        function()
          Snacks.picker.commands()
        end,
        desc = "Commands",
      },
      {
        "<leader>sd",
        function()
          Snacks.picker.diagnostics()
        end,
        desc = "Diagnostics",
      },
      {
        "<leader>sD",
        function()
          Snacks.picker.diagnostics_buffer()
        end,
        desc = "Buffer Diagnostics",
      },
      {
        "<leader>sh",
        function()
          Snacks.picker.help()
        end,
        desc = "Help Pages",
      },
      {
        "<leader>si",
        function()
          Snacks.picker.icons()
        end,
        desc = "Icons",
      },
      {
        "<leader>sj",
        function()
          Snacks.picker.jumps()
        end,
        desc = "Jumps",
      },
      {
        "<leader>sk",
        function()
          Snacks.picker.keymaps()
        end,
        desc = "Keymaps",
      },
      {
        "<leader>sm",
        function()
          Snacks.picker.marks()
        end,
        desc = "Marks",
      },
      {
        "<leader>su",
        function()
          Snacks.picker.undo()
        end,
        desc = "Undotree",
      },
      {
        "<leader>uC",
        function()
          Snacks.picker.colorschemes()
        end,
        desc = "Colorschemes",
      },
      -- Git
      {
        "<leader>gg",
        function()
          Snacks.lazygit()
        end,
        desc = "Lazygit (root)",
      },
      {
        "<leader>gl",
        function()
          Snacks.picker.git_log()
        end,
        desc = "Git Log",
      },
      {
        "<leader>gL",
        function()
          Snacks.picker.git_log({ cwd = vim.fn.expand("%:p:h") })
        end,
        desc = "Git Log (cwd)",
      },
      {
        "<leader>gb",
        function()
          Snacks.picker.git_log_line()
        end,
        desc = "Git Blame Line",
      },
      {
        "<leader>gf",
        function()
          Snacks.picker.git_log_file()
        end,
        desc = "Git Current File History",
      },
      {
        "<leader>gB",
        function()
          Snacks.gitbrowse()
        end,
        desc = "Git Browse",
        mode = { "n", "x" },
      },
      {
        "<leader>gs",
        function()
          Snacks.picker.git_status()
        end,
        desc = "Git Status",
      },
      {
        "<leader>gS",
        function()
          Snacks.picker.git_stash()
        end,
        desc = "Git Stash",
      },
      {
        "<leader>gd",
        function()
          Snacks.picker.git_diff()
        end,
        desc = "Git Diff (hunks)",
      },
      -- Terminal
      {
        "<c-_>",
        function()
          Snacks.terminal.toggle()
        end,
        desc = "Toggle Terminal",
        mode = { "n", "t" },
      },
      -- Scratch
      {
        "<leader>.",
        function()
          Snacks.scratch()
        end,
        desc = "Toggle Scratch Buffer",
      },
      {
        "<leader>S",
        function()
          Snacks.scratch.select()
        end,
        desc = "Select Scratch Buffer",
      },
      -- UI toggles
      {
        "<leader>uD",
        function()
          Snacks.toggle.dim():toggle()
        end,
        desc = "Toggle Dimming",
      },
      {
        "<leader>ua",
        function()
          Snacks.toggle.animate():toggle()
        end,
        desc = "Toggle Animations",
      },
      {
        "<leader>ug",
        function()
          Snacks.toggle.indent():toggle()
        end,
        desc = "Toggle Indent Guides",
      },
      {
        "<leader>uS",
        function()
          Snacks.toggle.scroll():toggle()
        end,
        desc = "Toggle Smooth Scroll",
      },
      {
        "<leader>uZ",
        function()
          Snacks.zen.zoom()
        end,
        desc = "Toggle Zoom",
      },
      {
        "<leader>wm",
        function()
          Snacks.zen.zoom()
        end,
        desc = "Toggle Zoom",
      },
      {
        "<leader>uz",
        function()
          Snacks.zen()
        end,
        desc = "Toggle Zen Mode",
      },
    },
  },

  -- Flash (jump/search)
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      {
        "s",
        function()
          require("flash").jump()
        end,
        desc = "Flash",
        mode = { "n", "x", "o" },
      },
    },
  },

  -- Grug-far (find and replace)
  {
    "MagicDuck/grug-far.nvim",
    opts = { headerMaxWidth = 80 },
    cmd = { "GrugFar", "GrugFarWithin" },
    keys = {
      {
        "<leader>sr",
        function()
          local grug = require("grug-far")
          local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
          grug.open({
            transient = true,
            prefills = {
              filesFilter = ext and ext ~= "" and "*." .. ext or nil,
            },
          })
        end,
        mode = { "n", "x" },
        desc = "Search and Replace",
      },
    },
  },

  -- Todo comments
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "VeryLazy",
    opts = {},
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next Todo Comment",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Previous Todo Comment",
      },
      {
        "<leader>st",
        function()
          Snacks.picker.todo_comments()
        end,
        desc = "Todo",
      },
    },
  },

  -- Dropbar (winbar breadcrumb)
  {
    "Bekaboo/dropbar.nvim",
    lazy = false,
    dependencies = {
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      require("dropbar").setup()
      local api = require("dropbar.api")
      vim.keymap.set("n", "<leader>;", api.pick, { desc = "Pick symbols in winbar" })
      vim.keymap.set("n", "[;", api.goto_context_start, { desc = "Go to start of current context" })
      vim.keymap.set("n", "];", api.select_next_context, { desc = "Select next context" })
    end,
  },
}
