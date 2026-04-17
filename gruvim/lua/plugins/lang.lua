return {

  -- SchemaStore (JSON/YAML schemas)
  {
    "b0o/SchemaStore.nvim",
    lazy = true,
    version = false,
  },

  -- JSON LSP
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function()
      vim.lsp.config("jsonls", {
        before_init = function(_, new_config)
          new_config.settings = new_config.settings or {}
          new_config.settings.json = new_config.settings.json or {}
          new_config.settings.json.schemas = new_config.settings.json.schemas or {}
          vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
        end,
        settings = {
          json = {
            format = { enable = true },
            validate = { enable = true },
          },
        },
      })
    end,
  },

  -- YAML LSP
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function()
      vim.lsp.config("yamlls", {
        capabilities = {
          textDocument = {
            foldingRange = {
              dynamicRegistration = false,
              lineFoldingOnly = true,
            },
          },
        },
        before_init = function(_, new_config)
          new_config.settings = new_config.settings or {}
          new_config.settings.yaml = new_config.settings.yaml or {}
          new_config.settings.yaml.schemas =
            vim.tbl_deep_extend("force", new_config.settings.yaml.schemas or {}, require("schemastore").yaml.schemas())
        end,
        settings = {
          redhat = { telemetry = { enabled = false } },
          yaml = {
            keyOrdering = false,
            format = { enable = true },
            validate = true,
          },
        },
      })
    end,
  },

  -- Markdown preview
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = function()
      require("lazy").load({ plugins = { "markdown-preview.nvim" } })
      vim.fn["mkdp#util#install"]()
    end,
    keys = {
      { "<leader>cp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview" },
    },
    config = function()
      vim.cmd([[do FileType]])
    end,
  },

  -- Render markdown
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "rmd", "org" },
    opts = {
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
      },
      heading = {
        sign = false,
        icons = {},
      },
      checkbox = {
        enabled = false,
      },
    },
    config = function(_, opts)
      local rm = require("render-markdown")
      rm.setup(opts)

      -- <leader>um: render-markdown 토글
      local enabled = true
      vim.keymap.set("n", "<leader>um", function()
        enabled = not enabled
        rm.set(enabled)
        vim.notify("Render Markdown: " .. (enabled and "ON" or "OFF"), vim.log.levels.INFO)
      end, { desc = "Toggle Render Markdown" })
    end,
  },

  -- Python venv selector
  {
    "linux-cultist/venv-selector.nvim",
    cmd = "VenvSelect",
    ft = "python",
    opts = {
      options = {
        notify_user_on_venv_activation = true,
      },
    },
    keys = {
      { "<leader>cv", "<cmd>VenvSelect<cr>", ft = "python", desc = "Select VirtualEnv" },
    },
  },

  -- Ansible
  {
    "mfussenegger/nvim-ansible",
    ft = { "yaml", "yaml.ansible" },
  },
}
