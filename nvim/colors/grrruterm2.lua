vim.o.termguicolors = true
vim.o.background = "dark"

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "grrruterm2"

local colors = {
  bg = "#101216",
  bg_alt = "#1a1a1a",
  bg_highlight = "#1e1e1e",
  fg = "#d6d6d6",
  fg_dim = "#98989d",
  black = "#000000",
  red = "#f78166",
  yellow = "#e3b341",
  blue = "#6ca4f8",
  cyan = "#2b7489",
  white = "#ffffff",
  bright_black = "#4d4d4d",
  bright_red = "#f78166",
  bright_yellow = "#e3b341",
  bright_blue = "#00a0c9",
  bright_cyan = "#3b9dc5",
  bright_white = "#ffffff",
  selection = "#3b5070",
  cursor = "#c9d1d9",
  cursor_text = "#101216",
}

vim.g.terminal_color_0 = colors.black
vim.g.terminal_color_1 = colors.red
vim.g.terminal_color_2 = colors.bright_blue
vim.g.terminal_color_3 = colors.blue
vim.g.terminal_color_4 = colors.blue
vim.g.terminal_color_5 = colors.yellow
vim.g.terminal_color_6 = colors.cyan
vim.g.terminal_color_7 = colors.white
vim.g.terminal_color_8 = colors.bright_black
vim.g.terminal_color_9 = colors.bright_red
vim.g.terminal_color_10 = colors.bright_yellow
vim.g.terminal_color_11 = colors.blue
vim.g.terminal_color_12 = colors.blue
vim.g.terminal_color_13 = colors.bright_yellow
vim.g.terminal_color_14 = colors.bright_cyan
vim.g.terminal_color_15 = colors.bright_white

local function hl(name, opts)
  vim.api.nvim_set_hl(0, name, opts)
end

local function link(name, target)
  vim.api.nvim_set_hl(0, name, { link = target })
end

hl("Normal", { fg = colors.fg, bg = colors.bg })
hl("NormalNC", { fg = colors.fg, bg = colors.bg })
hl("NormalFloat", { fg = colors.fg, bg = colors.bg_alt })
hl("FloatBorder", { fg = colors.bright_black, bg = colors.bg_alt })
hl("FloatTitle", { fg = colors.blue, bg = colors.bg_alt, bold = true })
hl("Cursor", { fg = colors.cursor_text, bg = colors.cursor })
hl("CursorLine", { bg = colors.bg_highlight })
hl("CursorColumn", { bg = colors.bg_highlight })
hl("CursorLineNr", { fg = colors.blue, bg = colors.bg_highlight, bold = true })
hl("LineNr", { fg = colors.bright_black, bg = colors.bg })
hl("SignColumn", { bg = colors.bg })
hl("FoldColumn", { fg = colors.bright_black, bg = colors.bg })
hl("Folded", { fg = colors.fg_dim, bg = colors.bg_alt })
hl("ColorColumn", { bg = colors.bg_highlight })
hl("WinSeparator", { fg = colors.bg_highlight })
hl("VertSplit", { fg = colors.bg_highlight })
hl("Visual", { bg = colors.selection })
hl("VisualNOS", { bg = colors.selection })
hl("Search", { fg = colors.bg, bg = colors.blue, bold = true })
hl("IncSearch", { fg = colors.bg, bg = colors.blue, bold = true })
hl("CurSearch", { fg = colors.bg, bg = colors.blue, bold = true })
hl("MatchParen", { fg = colors.blue, bg = colors.bg_highlight, bold = true })
hl("Pmenu", { fg = colors.fg, bg = colors.bg_alt })
hl("PmenuSel", { fg = colors.bg, bg = colors.blue, bold = true })
hl("PmenuSbar", { bg = colors.bg_highlight })
hl("PmenuThumb", { bg = colors.bright_black })
hl("WildMenu", { fg = colors.bg, bg = colors.blue, bold = true })
hl("StatusLine", { fg = colors.fg, bg = colors.bg_highlight })
hl("StatusLineNC", { fg = colors.bright_black, bg = colors.bg_alt })
hl("TabLine", { fg = colors.bright_black, bg = colors.bg_alt })
hl("TabLineSel", { fg = colors.fg, bg = colors.bg_highlight, bold = true })
hl("TabLineFill", { bg = colors.bg_alt })
hl("Title", { fg = colors.blue, bold = true })
hl("Directory", { fg = colors.blue })
hl("Question", { fg = colors.bright_blue, bold = true })
hl("MoreMsg", { fg = colors.bright_blue, bold = true })
hl("ModeMsg", { fg = colors.blue, bold = true })
hl("WarningMsg", { fg = colors.blue, bold = true })
hl("ErrorMsg", { fg = colors.red, bold = true })
hl("NonText", { fg = colors.bright_black })
hl("Whitespace", { fg = colors.bright_black })
hl("EndOfBuffer", { fg = colors.bg })
hl("SpecialKey", { fg = colors.bright_black })
hl("QuickFixLine", { fg = colors.fg, bg = colors.bg_highlight, bold = true })

hl("Comment", { fg = colors.fg_dim, italic = true })
hl("Constant", { fg = colors.blue })
hl("String", { fg = colors.bright_blue })
hl("Character", { fg = colors.bright_blue })
hl("Number", { fg = colors.blue })
hl("Boolean", { fg = colors.blue })
hl("Float", { fg = colors.blue })
hl("Identifier", { fg = colors.fg })
hl("Function", { fg = colors.blue })
hl("Statement", { fg = colors.red })
hl("Conditional", { fg = colors.red })
hl("Repeat", { fg = colors.red })
hl("Label", { fg = colors.red })
hl("Operator", { fg = colors.fg })
hl("Keyword", { fg = colors.red })
hl("Exception", { fg = colors.red })
hl("PreProc", { fg = colors.red })
hl("Include", { fg = colors.red })
hl("Define", { fg = colors.red })
hl("Macro", { fg = colors.red })
hl("PreCondit", { fg = colors.red })
hl("Type", { fg = colors.blue })
hl("StorageClass", { fg = colors.blue })
hl("Structure", { fg = colors.blue })
hl("Typedef", { fg = colors.blue })
hl("Special", { fg = colors.fg })
hl("SpecialChar", { fg = colors.fg })
hl("Delimiter", { fg = colors.fg })
hl("SpecialComment", { fg = colors.fg_dim })
hl("Debug", { fg = colors.fg })
hl("Tag", { fg = colors.bright_blue })
hl("Underlined", { fg = colors.blue, underline = true })
hl("Ignore", { fg = colors.bright_black })
hl("Error", { fg = colors.red })
hl("Todo", { fg = colors.yellow, bg = colors.bg_alt, bold = true })

hl("DiffAdd", { fg = colors.bright_blue, bg = colors.bg_alt })
hl("DiffChange", { fg = colors.blue, bg = colors.bg_alt })
hl("DiffDelete", { fg = colors.red, bg = colors.bg_alt })
hl("DiffText", { fg = colors.blue, bg = colors.bg_highlight, bold = true })

hl("DiagnosticError", { fg = colors.red })
hl("DiagnosticWarn", { fg = colors.blue })
hl("DiagnosticInfo", { fg = colors.blue })
hl("DiagnosticHint", { fg = colors.fg_dim })
hl("DiagnosticVirtualTextError", { fg = colors.red, bg = colors.bg_alt })
hl("DiagnosticVirtualTextWarn", { fg = colors.blue, bg = colors.bg_alt })
hl("DiagnosticVirtualTextInfo", { fg = colors.blue, bg = colors.bg_alt })
hl("DiagnosticVirtualTextHint", { fg = colors.fg_dim, bg = colors.bg_alt })
hl("DiagnosticUnderlineError", { undercurl = true, sp = colors.red })
hl("DiagnosticUnderlineWarn", { undercurl = true, sp = colors.blue })
hl("DiagnosticUnderlineInfo", { undercurl = true, sp = colors.blue })
hl("DiagnosticUnderlineHint", { undercurl = true, sp = colors.fg_dim })
hl("DiagnosticSignError", { fg = colors.red })
hl("DiagnosticSignWarn", { fg = colors.blue })
hl("DiagnosticSignInfo", { fg = colors.blue })
hl("DiagnosticSignHint", { fg = colors.fg_dim })

hl("LspReferenceText", { bg = colors.bg_highlight })
hl("LspReferenceRead", { bg = colors.bg_highlight })
hl("LspReferenceWrite", { bg = colors.bg_highlight })
hl("LspSignatureActiveParameter", { fg = colors.blue, bold = true })

hl("GitSignsAdd", { fg = colors.bright_blue })
hl("GitSignsChange", { fg = colors.blue })
hl("GitSignsDelete", { fg = colors.red })

hl("SpellBad", { undercurl = true, sp = colors.red })
hl("SpellCap", { undercurl = true, sp = colors.blue })
hl("SpellLocal", { undercurl = true, sp = colors.blue })
hl("SpellRare", { undercurl = true, sp = colors.blue })

link("@comment", "Comment")
link("@string", "String")
link("@string.documentation", "String")
link("@number", "Number")
link("@boolean", "Boolean")
link("@constant", "Constant")
link("@constant.builtin", "Constant")
link("@function", "Function")
link("@function.builtin", "Function")
link("@function.call", "Function")
link("@method", "Function")
link("@method.call", "Function")
link("@keyword", "Keyword")
link("@keyword.return", "Keyword")
link("@conditional", "Conditional")
link("@repeat", "Repeat")
link("@type", "Type")
link("@type.builtin", "Type")
link("@property", "Identifier")
link("@field", "Identifier")
link("@variable", "Identifier")
link("@variable.builtin", "Identifier")
link("@parameter", "Identifier")
link("@namespace", "Identifier")
link("@constructor", "Type")
link("@punctuation.delimiter", "Delimiter")
link("@punctuation.bracket", "Delimiter")
link("@punctuation.special", "Delimiter")
link("@operator", "Operator")
link("@tag", "Tag")
link("@tag.attribute", "Identifier")
link("@tag.delimiter", "Delimiter")
