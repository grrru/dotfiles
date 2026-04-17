return {

  -- LSP
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "mason-lspconfig.nvim",
    },
    config = function()
      -- Diagnostics
      vim.diagnostic.config({
        underline = { severity = { min = vim.diagnostic.severity.ERROR } },
        virtual_text = { severity = { min = vim.diagnostic.severity.ERROR } },
        signs = { severity = { min = vim.diagnostic.severity.ERROR } },
        update_in_insert = false,
        severity_sort = true,
      })

      -- Keymaps on LSP attach
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("gruvim_lsp_attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end

          map("gd", function()
            Snacks.picker.lsp_definitions()
          end, "Goto Definition")
          map("gr", function()
            Snacks.picker.lsp_references()
          end, "References")
          map("gI", function()
            Snacks.picker.lsp_implementations()
          end, "Goto Implementation")
          map("gy", function()
            Snacks.picker.lsp_type_definitions()
          end, "Goto Type Definition")
          map("gD", vim.lsp.buf.declaration, "Goto Declaration")
          map("K", vim.lsp.buf.hover, "Hover")
          map("gK", vim.lsp.buf.signature_help, "Signature Help")
          map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
          map("<leader>cR", function()
            Snacks.rename.rename_file()
          end, "Rename File")
          map("<leader>cl", function()
            Snacks.picker.lsp_config()
          end, "LSP Info")
          map("<leader>ss", function()
            Snacks.picker.lsp_symbols()
          end, "LSP Symbols")
          map("<leader>sS", function()
            Snacks.picker.lsp_workspace_symbols()
          end, "LSP Workspace Symbols")
          map("<leader>co", vim.lsp.buf.code_action, "Organize Imports")
          map("]]", function()
            Snacks.words.jump(vim.v.count1)
          end, "Next Reference")
          map("[[", function()
            Snacks.words.jump(-vim.v.count1)
          end, "Prev Reference")

          vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, { buffer = event.buf, desc = "Signature Help" })
          vim.keymap.set(
            { "n", "x" },
            "<leader>ca",
            vim.lsp.buf.code_action,
            { buffer = event.buf, desc = "Code Action" }
          )
        end,
      })

      -- Servers
      vim.lsp.config("gopls", {
        settings = {
          gopls = {
            gofumpt = false,
          },
        },
      })

      vim.lsp.config("basedpyright", {
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              autoImportCompletions = true,
            },
          },
        },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            completion = { callSnippet = "Replace" },
          },
        },
      })
    end,
  },

  -- Mason (LSP/tool installer)
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    keys = {
      { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" },
    },
    opts = {
      ensure_installed = {
        "stylua",
        "gopls",
        "basedpyright",
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)
    end,
  },

  -- Mason-lspconfig
  {
    "mason-org/mason-lspconfig.nvim",
    lazy = true,
    opts = {
      automatic_enable = true,
    },
  },

  -- Lazydev (Lua/Neovim dev LSP)
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },

  -- Trouble (diagnostics list)
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      modes = {
        lsp = { win = { position = "right" } },
      },
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
      { "<leader>cs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols (Trouble)" },
      { "<leader>cS", "<cmd>Trouble lsp toggle<cr>", desc = "LSP (Trouble)" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location List (Trouble)" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix List (Trouble)" },
      {
        "[q",
        function()
          if require("trouble").is_open() then
            require("trouble").prev({ skip_groups = true, jump = true })
          else
            pcall(vim.cmd.cprev)
          end
        end,
        desc = "Previous Trouble/Quickfix Item",
      },
      {
        "]q",
        function()
          if require("trouble").is_open() then
            require("trouble").next({ skip_groups = true, jump = true })
          else
            pcall(vim.cmd.cnext)
          end
        end,
        desc = "Next Trouble/Quickfix Item",
      },
    },
  },

  -- Inc-rename
  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    opts = {},
    keys = {
      {
        "<leader>cr",
        function()
          return ":" .. require("inc_rename").config.cmd_name .. " " .. vim.fn.expand("<cword>")
        end,
        expr = true,
        desc = "Rename (inc-rename)",
      },
    },
  },
}
