return {
  "folke/snacks.nvim",
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
          ignored = true,
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
      formats = { "png", "jpg", "jpeg", "gif", "webp", "pdf", "mp4", "mov", "bmp", "tiff" },
    },
  },
}
