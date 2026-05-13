return {

  -- Persistence (세션 저장/복원)
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    config = function()
      require("persistence").setup()

      local function close_codediff_tabs()
        local ok_session, codediff_session = pcall(require, "codediff.ui.lifecycle.session")
        local ok_cleanup, codediff_cleanup = pcall(require, "codediff.ui.lifecycle.cleanup")
        if not (ok_session and ok_cleanup) then
          return
        end

        local current_tab = vim.api.nvim_get_current_tabpage()
        local tabs = vim.tbl_keys(codediff_session.get_active_diffs())

        for _, tab in ipairs(tabs) do
          if vim.api.nvim_tabpage_is_valid(tab) then
            codediff_cleanup.cleanup_for_quit(tab)
            if #vim.api.nvim_list_tabpages() > 1 then
              vim.api.nvim_set_current_tabpage(tab)
              pcall(vim.cmd, "silent! tabclose")
            end
          end
        end

        if vim.api.nvim_tabpage_is_valid(current_tab) then
          vim.api.nvim_set_current_tabpage(current_tab)
        end
      end

      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistenceSavePre",
        callback = close_codediff_tabs,
      })
    end,
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").load()
        end,
        desc = "Restore Session",
      },
      {
        "<leader>qS",
        function()
          require("persistence").select()
        end,
        desc = "Select Session",
      },
      {
        "<leader>ql",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore Last Session",
      },
      {
        "<leader>qd",
        function()
          require("persistence").stop()
        end,
        desc = "Don't Save Current Session",
      },
    },
  },
}
