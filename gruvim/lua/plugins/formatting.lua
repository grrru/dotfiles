return {

  -- Conform (formatter)
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cF",
        function()
          require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 })
        end,
        mode = { "n", "x" },
        desc = "Format Injected Langs",
      },
    },
    opts = {
      default_format_opts = {
        timeout_ms = 3000,
        lsp_format = "fallback",
      },
      formatters_by_ft = {
        gdscript = { "gdscript-formatter" },
        lua = { "stylua", lsp_format = "never" },
        go = { "goimports" },
        sh = { "shfmt" },
        python = { "ruff_format" },
      },
      formatters = {
        injected = { options = { ignore_errors = true } },
      },
    },
    config = function(_, opts)
      require("conform").setup(opts)

      -- 전역/버퍼 포맷 토글 상태
      vim.g.autoformat = true

      local function format_enabled(buf)
        if vim.b[buf].autoformat ~= nil then
          return vim.b[buf].autoformat
        end
        return vim.g.autoformat
      end

      -- 저장 시 자동 포맷
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("gruvim_conform", { clear = true }),
        callback = function(event)
          if format_enabled(event.buf) then
            require("conform").format({ bufnr = event.buf })
          end
        end,
      })

      -- <leader>uf: 전역 포맷 토글
      vim.keymap.set("n", "<leader>uf", function()
        vim.g.autoformat = not vim.g.autoformat
        vim.notify("Auto Format (Global): " .. (vim.g.autoformat and "ON" or "OFF"), vim.log.levels.INFO)
      end, { desc = "Toggle Auto Format (Global)" })

      -- <leader>uF: 버퍼 포맷 토글
      vim.keymap.set("n", "<leader>uF", function()
        vim.b.autoformat = not format_enabled(vim.api.nvim_get_current_buf())
        vim.notify("Auto Format (Buffer): " .. (vim.b.autoformat and "ON" or "OFF"), vim.log.levels.INFO)
      end, { desc = "Toggle Auto Format (Buffer)" })
    end,
  },
}
