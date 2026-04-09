return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader><space>",
      function()
        Snacks.picker.files({ root = false })
      end,
      desc = "Find Files (cwd)",
    },
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
        Snacks.picker.explorer({ cwd = LazyVim.root() })
      end,
      desc = "Explorer (root)",
    },
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
        Snacks.picker.grep({ cwd = LazyVim.root() })
      end,
      desc = "Grep (root)",
    },
  },
  opts = {
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
      preset = {
        keys = {
          { icon = " ", key = "1", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "2", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "3", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "4", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          {
            icon = " ",
            key = "5",
            desc = "Config",
            action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
          },
          { icon = " ", key = "6", desc = "Restore Session", section = "session" },
          { icon = "󰒲 ", key = "7", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
          { icon = " ", key = "8", desc = "Quit", action = ":qa" },
        },
      },
    },
  },
}
