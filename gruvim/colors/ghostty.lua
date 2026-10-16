-- Ghostty's default dark look for Neovim: `:colorscheme ghostty`, or
-- NVIM_DARK_COLORSCHEME="ghostty" in theme.conf. The colors live in
-- lua/ghostty/palette.lua; this file only maps them onto highlight groups.
--
-- Syntax follows Tomorrow Night, which Ghostty's ANSI colors come from:
-- keywords magenta, functions blue, strings green, types yellow, numbers and
-- constants orange, parameters red, properties and operators cyan. Functions,
-- types and booleans are italic, like the catppuccin and nightfox styles in
-- plugins/ui.lua.

-- Re-read the palette, so editing it and running `:colorscheme ghostty` again
-- shows the change without a restart.
package.loaded["ghostty.palette"] = nil
local p = require("ghostty.palette")

-- `color` laid over `base` at `alpha` opacity, for tinted backgrounds.
local function blend(color, base, alpha)
  local function channel(hex, i)
    return tonumber(hex:sub(i, i + 1), 16)
  end
  local function mix(i)
    return math.floor(channel(color, i) * alpha + channel(base, i) * (1 - alpha) + 0.5)
  end
  return ("#%02x%02x%02x"):format(mix(2), mix(4), mix(6))
end

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.g.colors_name = "ghostty"

local groups = {
  -- Editor
  Normal = { fg = p.fg, bg = p.bg },
  NormalNC = { link = "Normal" },
  NormalFloat = { fg = p.fg, bg = p.bg_dark },
  FloatBorder = { fg = p.bg_bright, bg = p.bg_dark },
  FloatTitle = { fg = p.blue, bg = p.bg_dark, bold = true },
  FloatFooter = { fg = p.comment, bg = p.bg_dark },
  Cursor = { fg = p.bg, bg = p.fg },
  lCursor = { link = "Cursor" },
  CursorIM = { link = "Cursor" },
  TermCursor = { reverse = true },
  CursorLine = { bg = p.bg_light },
  CursorColumn = { bg = p.bg_light },
  ColorColumn = { bg = p.bg_light },
  CursorLineNr = { fg = p.yellow, bold = true },
  LineNr = { fg = p.line_nr },
  SignColumn = { fg = p.line_nr },
  FoldColumn = { fg = p.line_nr },
  Folded = { fg = p.comment, bg = p.bg_light },
  Conceal = { fg = p.comment },
  NonText = { fg = p.bg_bright },
  Whitespace = { fg = p.bg_bright },
  SpecialKey = { fg = p.bg_bright },
  EndOfBuffer = { fg = p.bg_visual },
  Directory = { fg = p.blue },
  MatchParen = { bg = p.bg_visual, bold = true },
  Search = { bg = blend(p.yellow, p.bg, 0.3) },
  CurSearch = { fg = p.bg, bg = p.yellow, bold = true },
  IncSearch = { link = "CurSearch" },
  Substitute = { fg = p.bg, bg = p.red },
  Visual = { bg = p.bg_visual },
  VisualNOS = { link = "Visual" },
  QuickFixLine = { bg = p.bg_visual, bold = true },
  Title = { fg = p.blue, bold = true },
  WinSeparator = { fg = p.bg_visual },
  VertSplit = { link = "WinSeparator" },
  WinBar = { fg = p.white },
  WinBarNC = { fg = p.comment },
  StatusLine = { fg = p.white, bg = p.bg_dark },
  StatusLineNC = { fg = p.comment, bg = p.bg_dark },
  TabLine = { fg = p.comment, bg = p.bg_dark },
  TabLineFill = { bg = p.bg_dark },
  TabLineSel = { fg = p.fg, bg = p.bg, bold = true },

  -- Popup menu
  Pmenu = { fg = p.white, bg = p.bg_dark },
  PmenuSel = { fg = p.fg, bg = p.bg_visual, bold = true },
  PmenuKind = { fg = p.blue, bg = p.bg_dark },
  PmenuKindSel = { fg = p.blue, bg = p.bg_visual, bold = true },
  PmenuExtra = { fg = p.comment, bg = p.bg_dark },
  PmenuExtraSel = { fg = p.comment, bg = p.bg_visual },
  PmenuMatch = { fg = p.blue, bold = true },
  PmenuMatchSel = { fg = p.blue, bold = true },
  PmenuSbar = { bg = p.bg_dark },
  PmenuThumb = { bg = p.bg_bright },
  WildMenu = { link = "PmenuSel" },

  -- Messages
  ErrorMsg = { fg = p.red, bold = true },
  WarningMsg = { fg = p.yellow },
  ModeMsg = { fg = p.fg, bold = true },
  MoreMsg = { fg = p.green },
  OkMsg = { fg = p.green },
  Question = { fg = p.green },

  -- Spelling
  SpellBad = { undercurl = true, sp = p.red },
  SpellCap = { undercurl = true, sp = p.yellow },
  SpellLocal = { undercurl = true, sp = p.cyan },
  SpellRare = { undercurl = true, sp = p.magenta },

  -- Diffs
  DiffAdd = { bg = blend(p.green, p.bg, 0.15) },
  DiffChange = { bg = blend(p.blue, p.bg, 0.15) },
  DiffDelete = { fg = blend(p.red, p.bg, 0.5), bg = blend(p.red, p.bg, 0.15) },
  DiffText = { bg = blend(p.blue, p.bg, 0.35) },
  Added = { fg = p.green },
  Changed = { fg = p.blue },
  Removed = { fg = p.red },

  -- Syntax. Neovim links the rest (Conditional, Include, Structure, ...) to
  -- these.
  Comment = { fg = p.comment },
  Constant = { fg = p.orange },
  String = { fg = p.green },
  Character = { fg = p.green },
  Number = { fg = p.orange },
  Boolean = { fg = p.orange, italic = true },
  Identifier = { fg = p.red },
  Function = { fg = p.blue, italic = true },
  Statement = { fg = p.magenta },
  Operator = { fg = p.cyan },
  PreProc = { fg = p.magenta },
  Type = { fg = p.yellow, italic = true },
  Special = { fg = p.cyan },
  Delimiter = { fg = p.white },
  Underlined = { underline = true },
  Bold = { bold = true },
  Italic = { italic = true },
  Ignore = { fg = p.bg_bright },
  Error = { fg = p.red },
  Todo = { fg = p.bg, bg = p.yellow, bold = true },

  -- Treesitter
  ["@variable"] = { fg = p.fg },
  ["@variable.builtin"] = { fg = p.red, italic = true },
  ["@variable.parameter"] = { fg = p.red },
  ["@variable.member"] = { fg = p.cyan },
  ["@property"] = { fg = p.cyan },
  ["@constant.macro"] = { fg = p.magenta },
  ["@module"] = { fg = p.yellow },
  ["@label"] = { fg = p.blue },
  ["@string.escape"] = { fg = p.cyan },
  ["@string.regexp"] = { fg = p.cyan },
  ["@string.special.symbol"] = { fg = p.orange },
  ["@string.special.url"] = { fg = p.cyan, underline = true },
  ["@function.builtin"] = { fg = p.cyan, italic = true },
  ["@constructor"] = { fg = p.yellow },
  ["@attribute"] = { fg = p.yellow },
  ["@punctuation.special"] = { fg = p.cyan },
  ["@tag"] = { fg = p.red },
  ["@tag.attribute"] = { fg = p.orange },
  ["@tag.delimiter"] = { fg = p.white },
  ["@comment.error"] = { fg = p.bg, bg = p.red, bold = true },
  ["@comment.warning"] = { fg = p.bg, bg = p.yellow, bold = true },
  ["@comment.todo"] = { fg = p.bg, bg = p.blue, bold = true },
  ["@comment.note"] = { fg = p.bg, bg = p.cyan, bold = true },
  ["@markup.strong"] = { bold = true },
  ["@markup.italic"] = { italic = true },
  ["@markup.strikethrough"] = { strikethrough = true },
  ["@markup.underline"] = { underline = true },
  ["@markup.heading"] = { fg = p.blue, bold = true },
  ["@markup.quote"] = { fg = p.comment, italic = true },
  ["@markup.math"] = { fg = p.blue },
  ["@markup.link"] = { fg = p.blue },
  ["@markup.link.url"] = { fg = p.cyan, underline = true },
  ["@markup.raw"] = { fg = p.green },
  ["@markup.list"] = { fg = p.red },
  ["@markup.list.checked"] = { fg = p.green },
  ["@markup.list.unchecked"] = { fg = p.comment },

  -- LSP
  LspReferenceText = { bg = p.bg_visual },
  LspReferenceRead = { link = "LspReferenceText" },
  LspReferenceWrite = { link = "LspReferenceText" },
  LspInlayHint = { fg = p.line_nr, italic = true },
  LspCodeLens = { fg = p.comment },
  LspSignatureActiveParameter = { fg = p.orange, bold = true },

  -- gitsigns. Without the word-diff groups it falls back to TermCursor
  -- (`reverse`), which turns each token's syntax color into its background.
  -- "Change" is the new side of a replaced word, so it shares Add's green.
  GitSignsAdd = { fg = p.green },
  GitSignsChange = { fg = p.blue },
  GitSignsDelete = { fg = p.red },
  GitSignsAddInline = { fg = p.bg, bg = p.green, bold = true },
  GitSignsChangeInline = { fg = p.bg, bg = p.green, bold = true },
  GitSignsDeleteInline = { fg = p.bg, bg = p.red, bold = true },
  GitSignsCurrentLineBlame = { fg = p.line_nr },

  -- flash.nvim
  FlashBackdrop = { fg = p.line_nr },
  FlashLabel = { fg = p.bg, bg = p.magenta, bold = true },

  -- mini.icons, which links these to diagnostic and syntax groups by default
  -- and so would draw purple icons orange (Constant).
  MiniIconsAzure = { fg = p.bright_blue },
  MiniIconsBlue = { fg = p.blue },
  MiniIconsCyan = { fg = p.cyan },
  MiniIconsGreen = { fg = p.green },
  MiniIconsGrey = { fg = p.white },
  MiniIconsOrange = { fg = p.orange },
  MiniIconsPurple = { fg = p.magenta },
  MiniIconsRed = { fg = p.red },
  MiniIconsYellow = { fg = p.yellow },
}

local diagnostics = { Error = p.red, Warn = p.yellow, Info = p.blue, Hint = p.cyan, Ok = p.green }
for kind, color in pairs(diagnostics) do
  groups["Diagnostic" .. kind] = { fg = color }
  groups["DiagnosticVirtualText" .. kind] = { fg = color, bg = blend(color, p.bg, 0.1) }
  groups["DiagnosticUnderline" .. kind] = { undercurl = true, sp = color }
end
groups.DiagnosticDeprecated = { strikethrough = true, sp = p.red }

-- Markdown headings, and render-markdown's heading backgrounds tinted to match
-- (it links them to the Diff* groups by default).
local headings = { p.red, p.orange, p.yellow, p.green, p.blue, p.magenta }
for level, color in ipairs(headings) do
  groups["@markup.heading." .. level] = { fg = color, bold = true }
  groups["RenderMarkdownH" .. level .. "Bg"] = { bg = blend(color, p.bg, 0.15) }
end

-- blink.cmp completion item kinds, colored like their syntax.
local kinds = {
  Text = p.white,
  Method = p.blue,
  Function = p.blue,
  Constructor = p.yellow,
  Field = p.cyan,
  Variable = p.fg,
  Property = p.cyan,
  Class = p.yellow,
  Interface = p.yellow,
  Struct = p.yellow,
  Module = p.yellow,
  Enum = p.yellow,
  TypeParameter = p.yellow,
  Unit = p.orange,
  Value = p.orange,
  Constant = p.orange,
  EnumMember = p.orange,
  Keyword = p.magenta,
  Event = p.magenta,
  Operator = p.cyan,
  Snippet = p.green,
  Color = p.red,
  Reference = p.red,
  File = p.blue,
  Folder = p.blue,
}
for kind, color in pairs(kinds) do
  groups["BlinkCmpKind" .. kind] = { fg = color }
end

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end

-- :terminal buffers (claude, sidekick's tmux) get the same ANSI colors as
-- Ghostty itself.
local terminal = {
  p.black,
  p.red,
  p.green,
  p.yellow,
  p.blue,
  p.magenta,
  p.cyan,
  p.white,
  p.bright_black,
  p.bright_red,
  p.bright_green,
  p.bright_yellow,
  p.bright_blue,
  p.bright_magenta,
  p.bright_cyan,
  p.bright_white,
}
for i, color in ipairs(terminal) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
