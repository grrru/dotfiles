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
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          {
            icon = " ",
            key = "c",
            desc = "Config",
            action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
          },
          { icon = " ", key = "r", desc = "Restore Session", section = "session" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
    },
  },
}
