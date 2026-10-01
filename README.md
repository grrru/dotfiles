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
| `macos/` | macOS LaunchAgents, copied into `~/Library/LaunchAgents` on macOS |
| `scripts/` | Standalone commands, added to `PATH` by `common.sh` |

## Installation

Requirements:

- macOS with Homebrew, or x86_64/arm64 Linux with `dnf` or `apt-get`
- Git and permission to install system packages
- tmux 3.6 or newer; the installer builds it from source where the package is older
- Neovim 0.12 or newer for Gruvim
- Tree-sitter CLI 0.26.1 or newer
- A Nerd Font for the configured icons; Ghostty defaults to D2CodingLigature Nerd Font

The installer uses the platform package manager for foundational CLI tools. On Linux,
it installs GitHub CLI from GitHub's official package repository and installs Neovim,
Tree-sitter CLI, Lazygit, and any required fzf fallback from verified upstream release
assets. Release downloads must include a matching SHA-256 digest and run on the host
before installation.

| Tool | Homebrew | Fedora (`dnf`) | Debian/Ubuntu (`apt-get`) |
| --- | --- | --- | --- |
| Base CLI tools | Homebrew formulas | Distribution packages | Distribution packages |
| tmux | Formula with version check | Package, then source build when older than 3.6 | Package, then source build when older than 3.6 |
| fd | `fd` formula | `fd-find` package | `fd-find` plus `~/.local/bin/fd` alias |
| fzf | Formula | Package, then release fallback | Package, then release fallback |
| Neovim / Tree-sitter CLI / Lazygit | Formulas | Verified upstream releases | Verified upstream releases |
| GitHub CLI | Formula | Official GitHub RPM repository | Official GitHub APT repository |

Standalone release binaries are installed in `~/.local/bin`. Neovim's complete
runtime tree is stored under `/opt` and exposed through a user-local symlink.

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
| `./install.sh bash` | Configure the Bash-to-Zsh hand-off only |
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
| Framework | `bash/bash_config.sh`, `zsh/zsh_config.sh` | Yes | oh-my-zsh, Powerlevel10k, completion, fzf, PATH cleanup, and the Bash-to-Zsh hand-off |
| Shared | `common.sh` | Yes | Portable helpers and defaults used by both shells |

Keep machine-specific settings in the local rc files: Go and Android SDK paths, nvm,
private aliases, company hosts, and secrets. `common.sh` owns shared user-bin paths, the
Mason bin path, locale defaults, `add_path`, `ecph`, and the `scripts/` directory on `PATH`.

When both tracked shell configs are installed, interactive Bash sessions hand off to
Zsh. A Bash started from Zsh stays Bash, so run `bash` or `exec bash` for a temporary
Bash session.

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
| Git | Gitsigns, Diffview+, Snacks Lazygit and Git pickers |
| UI | Catppuccin Latte, OneDarkPro, lualine, bufferline, Noice, which-key |
| Markdown | In-buffer rendering and browser preview |
| Sessions and AI | persistence.nvim and Sidekick |

### Language tooling

Run `:GruvimMasonInstall` after changing the managed list in
`gruvim/lua/config/mason.lua`.

- LSP servers: `ansible-language-server`, `bash-language-server`, `basedpyright`,
  `docker-compose-language-service`, `dockerfile-language-server`, `gopls`, `json-lsp`,
  `lua-language-server`, `marksman`, `ruff`, `vtsls`, and `yaml-language-server`
- Formatters: `gdscript-formatter`, `goimports`, `shfmt`, `stylua`, and Ruff's formatter
- Supporting tool: `shellcheck`
- External servers: `clangd` must be available on `PATH`; GDScript connects to Godot at
  `127.0.0.1:6005`

Mason's bin directory is appended to `PATH`, so tools explicitly installed by
`install.sh` take precedence and Mason fills only missing commands.

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
| `gra` / `<leader>cd` | LSP code action / line diagnostics |
| `<leader>cf` | Format the current buffer or selection |
| `<leader>uf` / `<leader>uF` | Toggle format-on-save globally / for the current buffer |
| `<leader>gg` | Open Lazygit at the Git root |
| `<leader>gv` / `<leader>gV` / `<leader>gm` | Open working-tree diff / history / main-branch review |
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
| `M-3` | Apply the three-pane layout |
| `g` | Hide the current pane, or restore the last hidden pane to where it was |
| `G` | Hide the current pane even when another pane is already hidden |

Ghostty configures the matching font, terminal colors, clipboard access, and the
`Ctrl-/` control sequence used by Neovim.

## Korean input on macOS

The macOS 27 built-in 2-Set Korean input source re-inserts the last jamo on backspace
in Ghostty and kitty, so use [Gureum](https://github.com/gureum/gureum)
(`brew install --cask gureumkim`) instead.

On macOS, `./install.sh config` installs a LaunchAgent that remaps right Command to F19
with `hidutil` at login. Set Gureum's Korean/English toggle shortcut to F19. Because the
key is no longer a modifier, typing quickly after toggling can't trigger Command
shortcuts such as `Cmd-D`. To undo the mapping for the current session, run
`hidutil property --set '{"UserKeyMapping":[]}'`.

## Theme switching

Run the script from Bash or Zsh:

```sh
toggle-theme            # flip light <-> dark
toggle-theme light      # force a mode
toggle-theme --apply    # re-apply the current mode (use after editing theme.conf)
```

Every theme setting lives in two files in the dotfiles root, and `toggle-theme` is the
only thing that reads them:

| File | Tracked | Holds |
| --- | --- | --- |
| `theme.defaults.conf` | yes | every key with its default (Catppuccin Latte / Frappe) |
| `theme.conf` | no (git-ignored) | only the keys that differ on this machine |

From those the script generates one file per tool and never reads them back, apart from
the mode:

| Generated | Read by |
| --- | --- |
| `ghostty/theme.local` | Ghostty (`config-file`); the script touches `ghostty/config` to reload it |
| `tmux/theme.local` | `tmux.conf`, which sources it, so `C-a r` and new servers keep the mode; also sourced into the running server |
| `~/.theme_mode` | Neovim, through a file watcher: the mode and the colorscheme |
| `theme` in `~/.claude/settings.json` | Claude Code, at startup |

All of them are rewritten from scratch on every run, so hand-edits do not survive.

Claude Code's theme defaults to `auto`, which follows the terminal's background in
running sessions too. tmux 3.6 or newer answers Claude Code's background queries with
the attached terminal's color and tells panes when it changes; `toggle-theme` asks each
tmux client's terminal for its color again, and Neovim sends the change to claude and
tmux clients in its terminal buffers. Under an older tmux, or with a fixed theme name
such as `light-daltonized`, only sessions started after the toggle change.

### Per-machine themes

Put only what differs into `theme.conf`, then apply it:

```sh
# ~/dotfiles/theme.conf
GHOSTTY_DARK_THEME="NightFox"
NVIM_DARK_COLORSCHEME="nightfox"
```

```sh
toggle-theme --apply
```

`theme.defaults.conf` documents every key. Changing a value there changes the default on
every machine. The script looks for the override in `$DOTFILES_THEME_CONF`,
`<dotfiles>/theme.conf`, and `~/.config/dotfiles/theme.conf`, in that order; the first
existing file wins. A `theme.conf` copied whole from the old `theme.conf.example` still
works, it just repeats the defaults.

Neovim colorschemes must come from a plugin it actually loads. This repo ships
catppuccin and nightfox; to use anything else on one machine, drop a lazy.nvim spec into
the git-ignored `gruvim/lua/local/plugins/`, which `init.lua` imports when present:

```lua
-- gruvim/lua/local/plugins/colorscheme.lua
return {
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
}
```

then set `NVIM_DARK_COLORSCHEME="tokyonight"` in `theme.conf`. If a configured
colorscheme cannot be loaded, Neovim warns and falls back to Catppuccin.

### Per-machine Ghostty settings

`ghostty/config` reads two optional files after itself: the generated `theme.local`, and
`local.conf` for everything else that differs per machine. `local.conf` is git-ignored,
hand-written, has no seed file, and is read last, so it overrides both:

```sh
# ~/dotfiles/ghostty/local.conf
font-size = 15
```

Ghostty picks it up on the next config reload (`Cmd-Shift-,`, or any `toggle-theme` run,
which touches `ghostty/config`).

## Git issue worktrees

`scripts/git-issue-worktree` sets up an issue branch plus a worktree across several
repositories at once, and tears them down again. `common.sh` puts `scripts/` on `PATH`, so
Git resolves it as a subcommand with no install step:

```sh
export WORKSPACE="$HOME/projects"   # where the repositories live
export WORKTREE="$HOME/worktrees"   # where worktrees are created
git issue-worktree setup 42
git issue-worktree clean 42
```

Both variables are required, so keep them in the machine-local rc file. `setup` asks for an
optional tag, which produces branch names such as `issue/42-auth-refactor`, then opens a
repository picker. Type a repository name to narrow the candidates by fuzzy match
(`bkapi` matches `backend-api`), `Tab` to select, `Enter` to confirm, `Esc` to cancel.
The picker is fzf, which `./install.sh deps` installs.

Repositories are discovered up to two directories below `WORKSPACE`, and the selection is
recorded in an `.issue-tracker` file inside the worktree base directory. `clean` reads that
file to remove the worktrees and branches, and asks before deleting the remote branch.

Requires Bash 4.3 or newer.
