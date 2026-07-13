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
        severity_sort = true,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          end
        end,
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
          map("grr", function()
            Snacks.picker.lsp_references({ include_current = true })
          end, "References")
          map("gri", function()
            Snacks.picker.lsp_implementations()
          end, "Goto Implementation")
          map("grt", function()
            Snacks.picker.lsp_type_definitions()
          end, "Goto Type Definition")
          map("gD", vim.lsp.buf.declaration, "Goto Declaration")
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

          map("<leader>co", vim.lsp.buf.code_action, "Code Action")

          map("gK", vim.lsp.buf.signature_help, "Signature Help")
          vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, { buffer = event.buf, desc = "Signature Help" })
        end,
      })

      -- Servers
      vim.lsp.config("basedpyright", {
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "off",
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

      vim.lsp.enable("clangd")

      vim.lsp.config("gdscript", {
        cmd = vim.lsp.rpc.connect("127.0.0.1", 6005),
      })
      vim.lsp.enable("gdscript")
    end,
  },

  -- Mason (LSP/tool installer)
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "GruvimMasonInstall" },
    keys = {
      { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" },
    },
    opts = require("config.mason"),
    config = function(_, opts)
      require("mason").setup(opts)

      local registry = require("mason-registry")
      local ensure_installed = opts.ensure_installed or {}

      vim.api.nvim_create_user_command("GruvimMasonInstall", function()
        registry.refresh(function()
          for _, package_name in ipairs(ensure_installed) do
            if registry.has_package(package_name) and not registry.is_installed(package_name) then
              local package = registry.get_package(package_name)
              package:install({}, function(success, result)
                if not success then
                  vim.schedule(function()
                    vim.notify(
                      ("Failed to install Mason package %s: %s"):format(package_name, result),
                      vim.log.levels.ERROR
                    )
                  end)
                end
              end)
            elseif not registry.has_package(package_name) then
              vim.schedule(function()
                vim.notify(("Unknown Mason package: %s"):format(package_name), vim.log.levels.WARN)
              end)
            end
          end
        end)
      end, { desc = "Install gruvim Mason packages" })
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
}
