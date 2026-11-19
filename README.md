# dotfiles

Personal workstation configuration for Neovim, Zsh, Bash, Ghostty, and herdr.
`install.sh` installs the shared tooling and links the tracked configuration into
the target user's home directory.

## Repository layout

| Path | Role |
| --- | --- |
| `install.sh` | Idempotent installer for dependencies, shells, and application configs ([details](docs/install.md)) |
| `gruvim/` | Neovim configuration, linked to `~/.config/nvim` ([README](gruvim/README.md)) |
| `zsh/`, `bash/` | Tracked shell framework configuration |
| `common.sh` | Portable PATH helpers, aliases, and defaults shared by Bash and Zsh |
| `ghostty/` | Ghostty configuration, linked when Ghostty is installed |
| `herdr/` | herdr configuration and pane layout presets, linked into `~/.config/herdr` when herdr is installed |
| `herdr/plugins/issue-tree/` | herdr plugin for issue worktrees across repositories ([README](herdr/plugins/issue-tree/README.md)) |
| `claude/` | Claude Code keybindings, linked to `~/.claude/keybindings.json` |
| `macos/` | macOS LaunchAgents, copied into `~/Library/LaunchAgents` on macOS; Korean input setup ([README](macos/README.md)) |
| `scripts/` | Standalone commands, added to `PATH` by `common.sh` |
| `theme.defaults.conf` | Light and dark theme settings for every tool, applied by `toggle-theme` ([docs](docs/theme.md)) |

## Installation

Needs macOS with Homebrew, or x86_64/arm64 Linux with `dnf` or `apt-get`. The full
requirements, installer targets, and where each tool comes from are in
[docs/install.md](docs/install.md).

```sh
git clone https://github.com/grrru/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Keep the checkout at a stable path, since shell startup files and application symlinks
point back into it. Existing application configs are moved to a `.bak` path before a new
symlink is created. Open Neovim once to let lazy.nvim install plugins, then run
`:GruvimMasonInstall`.

## Shell configuration

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

After each command, Zsh turns off mouse reporting, focus reports, and Kitty keyboard flags
before drawing the prompt, so a program that exits without restoring them (such as an SSH
session dropped while the Mac sleeps) doesn't leave keys arriving as escape codes like
`9;5u`.

## herdr

[herdr](https://herdr.dev) is a terminal multiplexer that tracks coding agents in its
panes. `herdr/config.toml` uses `C-a` as the prefix; press the prefix twice to send a
literal `C-a` to the pane. Its theme is set by `toggle-theme` (see
[Theme switching](#theme-switching)). Bindings that differ from herdr's defaults:

| Key | Action |
| --- | --- |
| `\|` | Split to the right |
| `1`–`9` | Switch to that workspace (tab number keys are unbound) |
| `M-1` | All panes side by side at equal widths (50:50 for two) |
| `M-2` | Two panes side by side, the focused one at 65% |
| `M-3` | Two panes stacked on the left (70:30) and one on the right, left:right 65:35 |
| `M-#` | `M-3` with the bottom-left pane as short as herdr allows (10% of the tab) |
| `i` / `I` | Issue tree list / new issue tree ([issue-tree](herdr/plugins/issue-tree/README.md)) |

In workspace navigation (`C-a w`), `j` / `k` move between workspaces and `C-j` / `C-k`
between panes. The layout presets are `herdr/scripts/pane-layout.sh`.

`~/.config/herdr` also holds the herdr server's sockets, logs, and session state, so
`./install.sh config` links only `config.toml` and `scripts/` into it. Inside a herdr pane,
Neovim yanks to the system clipboard over OSC 52 and Sidekick talks to herdr panes (see
[Gruvim](gruvim/README.md#sidekick)).

## Ghostty

Ghostty configures the matching font, terminal colors, clipboard access, and the
`Ctrl-/` control sequence used by Neovim. Per-machine settings go in the git-ignored
`ghostty/local.conf` (see [docs/theme.md](docs/theme.md#per-machine-ghostty-settings)).

## Claude Code keybindings

`claude/keybindings.json` adds scroll keys to the fullscreen conversation view, in
addition to `PgUp` / `PgDn`:

| Key | Action |
| --- | --- |
| `M-j` / `M-k` | Scroll down / up one line |
| `M-d` / `M-u` | Scroll down / up half a page |

Claude Code reloads the file a few seconds after it changes, through either path. `M-d`
is also the prompt's delete-word-forward key.

## Theme switching

`toggle-theme` switches Ghostty, Neovim, Claude Code, and herdr between light and dark
together:

```sh
toggle-theme            # flip light <-> dark
toggle-theme light      # force a mode
toggle-theme --apply    # re-apply the current mode (use after editing theme.conf)
```

Defaults live in `theme.defaults.conf` and per-machine overrides in the git-ignored
`theme.conf`. How each tool picks up the mode, and how to override themes per machine, is
in [docs/theme.md](docs/theme.md).
