return {

  -- Conform (formatter)
  {
    "stevearc/conform.nvim",
    lazy = true,
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
        async = false,
        quiet = false,
        lsp_format = "fallback",
      },
      formatters_by_ft = {
        lua = { "stylua" },
        go = { "goimports", "gofmt" },
        sh = { "shfmt" },
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
            require("conform").format({ bufnr = event.buf, lsp_format = "fallback" })
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

  -- nvim-lint (linter)
  {
    "mfussenegger/nvim-lint",
    event = { "BufWritePost", "BufReadPost", "InsertLeave" },
    opts = {
      linters_by_ft = {
        go = { "golangcilint" },
        python = { "ruff" },
      },
    },
    config = function(_, opts)
      local lint = require("lint")
      lint.linters_by_ft = opts.linters_by_ft

      local timer = vim.uv.new_timer()
      local function debounce(ms, fn)
        return function(...)
          local argv = { ... }
          timer:start(ms, 0, function()
            timer:stop()
            vim.schedule_wrap(fn)(unpack(argv))
          end)
        end
      end

      local function try_lint()
        local names = lint._resolve_linter_by_ft(vim.bo.filetype)
        names = vim.list_extend({}, names)
        if #names == 0 then
          vim.list_extend(names, lint.linters_by_ft["_"] or {})
        end
        vim.list_extend(names, lint.linters_by_ft["*"] or {})
        local ctx = { filename = vim.api.nvim_buf_get_name(0) }
        ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")
        names = vim.tbl_filter(function(name)
          local linter = lint.linters[name]
          return linter and not (type(linter) == "table" and linter.condition and not linter.condition(ctx))
        end, names)
        if #names > 0 then
          lint.try_lint(names)
        end
      end

      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("gruvim_lint", { clear = true }),
        callback = debounce(100, try_lint),
      })
    end,
  },
}
