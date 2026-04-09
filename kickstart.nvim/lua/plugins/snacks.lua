return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    {
      '<leader><space>',
      function() Snacks.picker.files { root = false } end,
      desc = 'Find Files (cwd)',
    },
    {
      '<leader>e',
      function() Snacks.explorer() end,
      desc = 'Explorer (cwd)',
    },
    {
      '<leader>E',
      function() Snacks.picker.explorer { cwd = vim.fn.getcwd() } end,
      desc = 'Explorer (root)',
    },
    {
      '<leader>sg',
      function() Snacks.picker.grep { root = false } end,
      desc = 'Grep (cwd)',
    },
    {
      '<leader>sG',
      function() Snacks.picker.grep { cwd = vim.fn.getcwd() } end,
      desc = 'Grep (root)',
    },
  },
  opts = {
    dashboard = { enabled = false },
    explorer = { enabled = true },
    indent = { enabled = true },
    statuscolumn = { enabled = true },
    picker = {
      enabled = true,
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
            if item.severity and item.severity > vim.diagnostic.severity.ERROR then item.severity = nil end
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
      formats = { 'png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf', 'mp4', 'mov', 'bmp', 'tiff', 'ico' },
    },
  },
}
