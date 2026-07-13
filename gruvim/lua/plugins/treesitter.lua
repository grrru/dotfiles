local parsers = {
  "bash",
  "c",
  "diff",
  "gdscript",
  "go",
  "gomod",
  "gosum",
  "html",
  "javascript",
  "json",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "regex",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

return {

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    version = false,
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")
      treesitter.install(parsers)

      -- Enable Tree-sitter highlighting on FileType events
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("gruvim_treesitter_highlight", { clear = true }),
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },

  -- Treesitter context (상단 컨텍스트 표시)
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
    opts = {
      mode = "cursor",
      max_lines = 2,
      trim_scope = "inner",
    },
    config = function(_, opts)
      require("treesitter-context").setup(opts)
      vim.api.nvim_set_hl(0, "TreesitterContextBottom", { underline = false })
      vim.api.nvim_set_hl(0, "TreesitterContextLineNumberBottom", { underline = false })
    end,
  },

  -- Treesitter textobjects (함수 단위 이동 및 선택)
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = "VeryLazy",
    keys = {
      { "]f", desc = "Next function start" },
      { "]F", desc = "Next function end" },
      { "[f", desc = "Prev function start" },
      { "[F", desc = "Prev function end" },
    },
    config = function()
      local move = require("nvim-treesitter-textobjects.move")

      local function map(lhs, fn, modes)
        vim.keymap.set(modes or { "n", "x", "o" }, lhs, fn, { silent = true })
      end

      map("]f", function()
        move.goto_next_start("@function.outer")
      end)
      map("]F", function()
        move.goto_next_end("@function.outer")
      end)
      map("[f", function()
        move.goto_previous_start("@function.outer")
      end)
      map("[F", function()
        move.goto_previous_end("@function.outer")
      end)
    end,
  },

  -- Autotag (HTML/JSX 태그 자동 닫기)
  {
    "windwp/nvim-ts-autotag",
    event = "VeryLazy",
    opts = {},
  },
}
