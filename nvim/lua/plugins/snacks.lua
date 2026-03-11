return {
  "folke/snacks.nvim",
  keys = {
    { "<leader><space>", function() Snacks.picker.files({ root = false }) end, desc = "Find Files (cwd)" },
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
