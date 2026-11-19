# Gruvim

[Back to README](../README.md)

Gruvim is a Lua-based Neovim configuration built around native LSP and diagnostics,
linked to `~/.config/nvim`. The plugin specs live under `lua/plugins/`; this page covers
the feature boundaries, not every dependency.

| Area | Main components |
| --- | --- |
| Plugin management | lazy.nvim with a pinned `lazy-lock.json` |
| Editing | blink.cmp, friendly-snippets, mini.pairs, Yanky, Treesitter comments |
| Navigation and search | Snacks picker/explorer, Flash, Grug Far, Dropbar |
| Language support | Native Neovim LSP, nvim-lspconfig, Mason, SchemaStore, LazyDev |
| Syntax | Treesitter highlighting, context, textobjects, and autotagging |
| Formatting | Conform with format-on-save enabled by default |
| Git | Gitsigns, Snacks Lazygit and Git pickers |
| UI | Catppuccin Latte, OneDarkPro, lualine, bufferline, Noice, which-key |
| Markdown | In-buffer rendering and browser preview |
| Sessions and AI | persistence.nvim and Sidekick |

## Language tooling

Run `:GruvimMasonInstall` after the first start and after changing the managed list in
`lua/config/mason.lua`.

- LSP servers: `ansible-language-server`, `bash-language-server`, `basedpyright`,
  `docker-compose-language-service`, `dockerfile-language-server`, `gopls`, `json-lsp`,
  `lua-language-server`, `marksman`, `ruff`, `vtsls`, `yaml-language-server`,
  `kotlin-lsp`, `gradle-language-server`, and `terraform-ls`
- Formatters: `biome`, `gdscript-formatter`, `goimports`, `shfmt`, `stylua`, and Ruff's
  formatter
- Supporting tool: `shellcheck`
- External servers: `clangd` must be available on `PATH`; GDScript connects to Godot at
  `127.0.0.1:6005`

Mason's bin directory comes last on `PATH`, so tools installed by `install.sh` win.
Diagnostics come from the language servers (ShellCheck through the Bash language server);
there is no separate lint runner.

Conform formats on save and falls back to LSP formatting. Explicit formatters:

| Filetype | Formatter |
| --- | --- |
| GDScript | `gdscript-formatter` |
| Go | `goimports` |
| Lua | `stylua` |
| Python | `ruff_format` |
| Shell | `shfmt` |

## Keymaps

`Space` is the leader key and `\` is the local leader. Press `<leader>?` for mappings
local to the current buffer or `<leader>sk` to search all mappings.

| Key | Action |
| --- | --- |
| `<leader><space>` / `<leader>ff` | Find files from the current directory / project root |
| `<leader>e` / `<leader>E` | Open the explorer at the current directory / Git root |
| `<leader>sg` / `<leader>sG` | Grep from the current directory / project root |
| `<S-h>` / `<S-l>` | Move to the previous / next buffer |
| `<leader>bd` | Delete the current buffer |
| `gd` / `grr` / `gri` / `grt` | LSP definition / references / implementation / type definition |
| `gra` / `<leader>cd` | LSP code action / line diagnostics |
| `<leader>cf` | Format the current buffer or selection |
| `<leader>uf` / `<leader>uF` | Toggle format-on-save globally / for the current buffer |
| `<leader>gg` | Open Lazygit at the Git root |
| `<leader>gv` / `<leader>gV` / `<leader>gm` | Open working-tree diff / history / main-branch review |
| `Ctrl-/` | Toggle the terminal |
| `<leader>cp` / `<leader>um` | Toggle Markdown preview / in-buffer rendering |
| `<leader>cv` | Select a Python virtual environment |
| `<leader>cm` | Open Mason (`:Lazy` manages plugins) |

## Sidekick

Sidekick sends `@file` references, lines, and selections from Neovim to an AI CLI such as
Claude Code running next to it (`<leader>at`, `<leader>al`, `<leader>af`, `<leader>av`).
When Neovim runs inside a [herdr](https://herdr.dev) pane (`HERDR_ENV=1`), the CLI runs in
a herdr pane; elsewhere it runs in a Neovim terminal.

Under herdr, `lua/config/sidekick_herdr.lua` provides the session backend:

- Sends go straight to the agent in Neovim's own herdr tab when the tab has exactly one;
  otherwise Sidekick opens its picker, which shows each agent's terminal title.
- `<leader>aa` focuses that agent's pane.
- A session started from the picker opens in a herdr split taking 32% of the Neovim pane.
