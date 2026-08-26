-- Drive Pantran's operator with a fixed mode and, in normal mode, a motion
local function translate(mode, motion)
  return function()
    local keys = require("pantran").motion_translate({ mode = mode }) .. (motion or "")
    vim.api.nvim_feedkeys(keys, "n", false)
  end
end

return {

  -- blink.cmp
  {
    "saghen/blink.cmp",
    version = "*",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    event = { "InsertEnter", "CmdlineEnter" },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset = "enter",
      },
      appearance = {
        use_nvim_cmp_as_default = false,
        nerd_font_variant = "mono",
      },
      snippets = {
        preset = "default",
      },
      completion = {
        accept = {
          auto_brackets = { enabled = true },
        },
        menu = {
          draw = {
            treesitter = { "lsp" },
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },
        ghost_text = { enabled = false },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          lua = { inherit_defaults = true, "lazydev" },
        },
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            score_offset = 100,
          },
        },
      },
      cmdline = {
        enabled = true,
        keymap = {
          preset = "cmdline",
          ["<Right>"] = false,
          ["<Left>"] = false,
        },
        completion = {
          list = { selection = { preselect = false } },
          menu = {
            auto_show = function(ctx)
              return vim.fn.getcmdtype() == ":"
            end,
          },
          ghost_text = { enabled = true },
        },
      },
    },
    config = function(_, opts)
      require("blink.cmp").setup(opts)
    end,
  },

  -- Mini.pairs
  {
    "echasnovski/mini.pairs",
    event = "VeryLazy",
    opts = {},
  },

  -- Mini.icons
  {
    "echasnovski/mini.icons",
    lazy = true,
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- Mini.hipatterns
  {
    "echasnovski/mini.hipatterns",
    event = "VeryLazy",
    opts = function()
      local hi = require("mini.hipatterns")
      return {
        highlighters = {
          hex_color = hi.gen_highlighter.hex_color({ priority = 2000 }),
        },
      }
    end,
  },

  -- ts-comments
  {
    "folke/ts-comments.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Pantran (translation)
  {
    "potamides/pantran.nvim",
    cmd = "Pantran",
    opts = {
      -- Without an API key the google engine falls back to the free web
      -- endpoints, trying clients5.google.com when translate.googleapis.com
      -- rate limits the request
      default_engine = "google",
      engines = {
        google = {
          fallback = {
            default_source = "auto",
            default_target = "ko",
          },
        },
      },
    },
    keys = {
      { "<leader>tw", translate("hover", "iw"), desc = "Translate Word" },
      { "<leader>tw", translate("hover"), mode = "x", desc = "Translate Selection" },
      { "<leader>tl", translate("hover", "_"), desc = "Translate Line" },
      { "<leader>tr", translate("replace"), mode = "x", desc = "Translate and Replace Selection" },
      { "<leader>tt", "<Cmd>Pantran<CR>", desc = "Translate Interactively" },
    },
  },

  -- Yanky (yank history)
  {
    "gbprod/yanky.nvim",
    event = "VeryLazy",
    opts = {
      system_clipboard = {
        sync_with_ring = not vim.env.SSH_CONNECTION,
      },
      highlight = { timer = 150 },
    },
    keys = {
      {
        "<leader>p",
        function()
          Snacks.picker.yanky()
        end,
        mode = { "n", "x" },
        desc = "Open Yank History",
      },
      { "y", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "Yank Text" },
      { "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" }, desc = "Put Text After Cursor" },
      { "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" }, desc = "Put Text Before Cursor" },
      {
        "[y",
        "<Plug>(YankyCycleForward)",
        desc = "Cycle Forward Through Yank History",
      },
      {
        "]y",
        "<Plug>(YankyCycleBackward)",
        desc = "Cycle Backward Through Yank History",
      },
      {
        "]p",
        "<Plug>(YankyPutIndentAfterLinewise)",
        desc = "Put Indented After Cursor (Linewise)",
      },
      {
        "[p",
        "<Plug>(YankyPutIndentBeforeLinewise)",
        desc = "Put Indented Before Cursor (Linewise)",
      },
    },
  },
}
