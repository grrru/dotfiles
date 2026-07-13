# dotfiles

Personal workstation configuration for Neovim, tmux, Zsh, Bash, and Ghostty.
`install.sh` installs the shared tooling and links the tracked configuration into
the target user's home directory.

## Repository layout

| Path | Role |
| --- | --- |
| `install.sh` | Idempotent installer for dependencies, shells, application configs, and tpm |
| `gruvim/` | Neovim configuration, linked to `~/.config/nvim` |
| `tmux/` | tmux configuration and layout helpers, linked to `~/.config/tmux` |
| `zsh/`, `bash/` | Tracked shell framework configuration |
| `common.sh` | Portable PATH helpers, aliases, and defaults shared by Bash and Zsh |
| `ghostty/` | Ghostty configuration, linked when Ghostty is installed |
| `scripts/` | Utilities shared by the configured applications |

## Installation

Requirements:

- macOS with Homebrew, or Linux with `dnf` or `apt-get`
- Git and permission to install system packages
- Neovim 0.11 or newer for Gruvim
- A Nerd Font for the configured icons; Ghostty defaults to D2CodingLigature Nerd Font

The installer attempts to install the appropriate CLI dependencies for the detected
package manager. Distribution repositories do not always provide a recent enough
Neovim, so verify its version separately.

```sh
git clone https://github.com/grrru/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Keep the checkout at a stable path. Shell startup files and application symlinks point
back into this repository. Existing application configs are moved to a `.bak` path
before a new symlink is created.

### Installer targets

`all` is the default target.

| Command | Action |
| --- | --- |
| `./install.sh` | Install dependencies, both shell setups, application configs, and tpm |
| `./install.sh deps` | Install CLI dependencies only |
| `./install.sh shell` | Install and configure both Bash and Zsh |
| `./install.sh bash` | Configure oh-my-bash only |
| `./install.sh zsh` | Configure oh-my-zsh, Powerlevel10k, and zsh-autosuggestions |
| `./install.sh config` | Link Neovim, tmux, and optionally Ghostty configs |
| `./install.sh tpm` | Install tmux Plugin Manager only |
| `./install.sh help` | Show command-line help |

To install user-level files for another account:

```sh
./install.sh --user target_user
./install.sh --user target_user config
```

The checkout must be readable by `target_user`.

### Post-install setup

Open Neovim once to let lazy.nvim install plugins, then install the tools managed by
Gruvim's Mason list:

```vim
:GruvimMasonInstall
```

Open tmux and press `C-a I` to install the plugins declared in `tmux.conf`.

## Shell configuration

Shell configuration is divided into tracked, portable layers and machine-local startup
files:

| Layer | File | Tracked | Responsibility |
| --- | --- | --- | --- |
| Entry point | `~/.bashrc`, `~/.zshrc` | No | Secrets, host-specific paths, runtime setup, and sourcing the repo config |
| Framework | `bash/bash_config.sh`, `zsh/zsh_config.sh` | Yes | oh-my-bash/oh-my-zsh, Powerlevel10k, completion, fzf, and PATH cleanup |
| Shared | `common.sh` | Yes | Portable helpers and defaults used by both shells |

Keep machine-specific settings in the local rc files: Go and Android SDK paths, nvm,
private aliases, company hosts, and secrets. `common.sh` owns shared user-bin paths, the
Mason bin path, locale defaults, `add_path`, `ecph`, and the `toggletheme` alias.

When both tracked shell configs are installed, interactive Bash sessions hand off to
Zsh. Run `exec bash` for a temporary Bash session.

## Gruvim

Gruvim is a Lua-based Neovim configuration built around native LSP and diagnostics.
The complete plugin specs live under `gruvim/lua/plugins/`; this section documents the
stable feature boundaries instead of duplicating every dependency.

| Area | Main components |
| --- | --- |
| Plugin management | lazy.nvim with a pinned `lazy-lock.json` |
| Editing | blink.cmp, friendly-snippets, mini.pairs, Yanky, Treesitter comments |
| Navigation and search | Snacks picker/explorer, Flash, Grug Far, Dropbar |
| Language support | Native Neovim LSP, nvim-lspconfig, Mason, SchemaStore, LazyDev |
| Syntax | Treesitter highlighting, context, textobjects, and autotagging |
| Formatting | Conform with format-on-save enabled by default |
| Git | Gitsigns, CodeDiff, Snacks Lazygit and Git pickers |
| UI | Catppuccin Latte, TokyoNight Moon, lualine, bufferline, Noice, which-key |
| Markdown | In-buffer rendering and browser preview |
| Sessions and AI | persistence.nvim and Sidekick |

### Language tooling

Run `:GruvimMasonInstall` after changing the managed list in
`gruvim/lua/config/mason.lua`.

- LSP servers: `ansible-language-server`, `bash-language-server`, `basedpyright`,
  `docker-compose-language-service`, `dockerfile-language-server`, `gopls`, `json-lsp`,
  `lua-language-server`, `marksman`, `ruff`, `vtsls`, and `yaml-language-server`
- Formatters: `gdscript-formatter`, `goimports`, `shfmt`, `stylua`, and Ruff's formatter
- Supporting tools: `shellcheck` and `tree-sitter-cli`
- External servers: `clangd` must be available on `PATH`; GDScript connects to Godot at
  `127.0.0.1:6005`

Diagnostics come from language servers. Bash language server uses ShellCheck for shell
diagnostics; there is no separate general-purpose lint runner in Gruvim.

Conform formats on save and uses LSP formatting as a fallback. Explicit formatter
mappings are:

| Filetype | Formatter |
| --- | --- |
| GDScript | `gdscript-formatter` |
| Go | `goimports` |
| Lua | `stylua` |
| Python | `ruff_format` |
| Shell | `shfmt` |

### Keymaps

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
| `<leader>co` / `<leader>cd` | LSP code action / line diagnostics |
| `<leader>cf` | Format the current buffer or selection |
| `<leader>uf` / `<leader>uF` | Toggle format-on-save globally / for the current buffer |
| `<leader>gg` | Open Lazygit at the Git root |
| `<leader>gv` / `<leader>gV` | Open CodeDiff explorer / history |
| `Ctrl-/` | Toggle the terminal |
| `<leader>cp` / `<leader>um` | Toggle Markdown preview / in-buffer rendering |
| `<leader>cv` | Select a Python virtual environment |

Use `:Lazy` for plugin management, `:Mason` for the tool registry, and `<leader>cm` as
the Mason shortcut.

## tmux and Ghostty

tmux uses `C-a` as its prefix, vi copy mode, mouse support, and true color. Common
prefix bindings include:

| Key | Action |
| --- | --- |
| `\|` / `-` | Split horizontally / vertically in the current directory |
| `h` / `j` / `k` / `l` | Move between panes |
| `H` / `J` / `K` / `L` | Resize panes |
| `r` | Reload `tmux.conf` |
| `M-2` | Apply the two-pane layout |
| `M-3` / `M-#` | Apply the regular / compact three-pane layout |

Ghostty configures the matching font, terminal colors, clipboard access, and the
`Ctrl-/` control sequence used by Neovim.

## Theme switching

Run the shared alias from Bash or Zsh:

```sh
toggletheme
```

It switches between Catppuccin Latte and TokyoNight Moon, updating `~/.theme_mode`,
Ghostty's ignored `ghostty/theme.local`, tmux colors, and the running Neovim colorscheme.
