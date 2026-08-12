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

local function toggle_explorer(path)
  local tree = require("nvim-tree.api").tree
  local current_root = require("nvim-tree.core").get_cwd()
  local target_root = vim.uv.fs_realpath(path) or path
  if current_root == target_root then
    tree.toggle()
  else
    tree.toggle({ path = path })
  end
end

-- Called by lazygit (see the lazygit os.edit config below) over --remote-expr,
-- which blocks until nvim answers. That gives the shell a barrier: once it
-- returns, the lazygit window is gone and the following --remote edit lands in
-- the window that had focus before lazygit opened. hide() keeps the buffer, so
-- the pty stays open and the lazygit session resumes on the next toggle.
function _G.snacks_lazygit_hide()
  for _, term in ipairs(Snacks.terminal.list()) do
    local cmd = type(term.cmd) == "table" and term.cmd[1] or term.cmd
    if cmd == "lazygit" and term:valid() then
      term:hide()
    end
  end
  return 1
end

return {

  -- Snacks (picker, dashboard, image, scratch, etc.)
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
            width = 0.95,
            height = 0.9,
          },
        },
        sources = {
          files = {
            hidden = true,
            ignored = true,
          },
        },
        formatters = {
          file = {
            filename_first = true,
            truncate = "left",
          },
        },
      },
      lazygit = {
        win = {
          width = 0,
          height = 0,
          border = "none",
        },
        -- The built-in nvim-remote preset hardcodes --remote-tab, so editing a
        -- file always lands in a new tab. Hide the lazygit window first (a
        -- blocking --remote-expr, so no race), then --remote edits in the window
        -- that had focus before. --remote takes the filename as an argument, so
        -- lazygit's own quoting keeps working.
        config = {
          os = {
            edit = 'nvim --server "$NVIM" --remote-expr "v:lua.snacks_lazygit_hide()" && nvim --server "$NVIM" --remote {{filename}}',
            editAtLine = 'nvim --server "$NVIM" --remote-expr "v:lua.snacks_lazygit_hide()" && nvim --server "$NVIM" --remote {{filename}} && nvim --server "$NVIM" --remote-send ":{{line}}<CR>"',
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
      terminal = {
        enabled = true,
        win = {
          height = 0.3,
        },
      },
      notifier = { enabled = true },
      scope = { enabled = true },
      indent = { enabled = true },
      scroll = { enabled = false },
      animate = { enabled = false },
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
        "<leader>fc",
        function()
          Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
        end,
        desc = "Find Config File",
      },
      {
        "<leader>bb",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Buffers",
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
          local root = vim.fs.root(0, { ".git" })
          Snacks.lazygit({ cwd = root or vim.uv.cwd() })
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
        "<leader>ud",
        function()
          Snacks.toggle.diagnostics():toggle()
        end,
        desc = "Toggle Diagnostics",
      },
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
        "<leader>uz",
        function()
          Snacks.zen()
        end,
        desc = "Toggle Zen Mode",
      },
    },
  },

  -- Nvim-tree
  {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    dependencies = { "echasnovski/mini.icons" },
    init = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
    opts = {
      -- Worktree layout: the root holds several repos and each tab :tcd's into
      -- one of them. Neovim fires DirChanged (scope=tabpage) both on :tcd and
      -- on entering a tab with a different local cwd, so this keeps the tree
      -- root following the active tab instead of freezing at the first cwd.
      sync_root_with_cwd = true,
      respect_buf_cwd = true,
      view = {
        signcolumn = "no",
      },
      renderer = {
        root_folder_label = function(path)
          return vim.fn.fnamemodify(path, ":t")
        end,
        group_empty = function(path)
          return path:gsub("/", ".")
        end,
      },
      diagnostics = {
        enable = true,
        severity = {
          min = vim.diagnostic.severity.ERROR,
        },
      },
      filters = {
        git_ignored = true,
      },
    },
    keys = {
      {
        "<leader>e",
        function()
          toggle_explorer(vim.uv.cwd())
        end,
        desc = "Explorer (cwd)",
      },
      {
        "<leader>E",
        function()
          local root = vim.fs.root(0, { ".git" })
          toggle_explorer(root or vim.uv.cwd())
        end,
        desc = "Explorer (git root)",
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
      {
        "<leader>sR",
        function()
          require("grug-far").open({
            transient = true,
            prefills = {
              paths = vim.fn.expand("%:p"),
            },
          })
        end,
        desc = "Search and Replace Current File",
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
      require("dropbar").setup({
        sources = {
          lsp = {
            valid_symbols = {
              "File",
              "Module",
              "Namespace",
              "Package",
              "Class",
              "Struct",
              "Interface",
              "Enum",
              "Constructor",
              "Function",
              "Method",
            },
          },
          treesitter = {
            valid_types = {
              "class",
              "struct",
              "interface",
              "enum",
              "constructor",
              "function",
              "method",
            },
          },
        },
      })
      local api = require("dropbar.api")
      vim.keymap.set("n", "<leader>;", api.pick, { desc = "Pick symbols in winbar" })
      vim.keymap.set("n", "[;", api.goto_context_start, { desc = "Go to start of current context" })
      vim.keymap.set("n", "];", api.select_next_context, { desc = "Select next context" })
    end,
  },
}
