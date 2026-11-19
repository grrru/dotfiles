# Installation details

[Back to README](../README.md)

## Requirements

- macOS with Homebrew, or x86_64/arm64 Linux with `dnf` or `apt-get`
- Git and permission to install system packages
- Neovim 0.12 or newer for Gruvim
- Tree-sitter CLI 0.26.1 or newer
- A Nerd Font for the configured icons; Ghostty defaults to D2CodingLigature Nerd Font

## Where tools come from

The installer uses the platform package manager for foundational CLI tools. On Linux, it
installs GitHub CLI from GitHub's official package repository, and Neovim, Tree-sitter
CLI, Lazygit, and any required fzf fallback from upstream release assets. A release
download must match its SHA-256 digest and run on the host before it is installed.

| Tool | Homebrew | Fedora (`dnf`) | Debian/Ubuntu (`apt-get`) |
| --- | --- | --- | --- |
| Base CLI tools | Homebrew formulas | Distribution packages | Distribution packages |
| fd | `fd` formula | `fd-find` package | `fd-find` plus `~/.local/bin/fd` alias |
| fzf | Formula | Package, then release fallback | Package, then release fallback |
| Neovim / Tree-sitter CLI / Lazygit | Formulas | Verified upstream releases | Verified upstream releases |
| GitHub CLI | Formula | Official GitHub RPM repository | Official GitHub APT repository |

Standalone release binaries go in `~/.local/bin`. Neovim's runtime tree is stored under
`/opt` and exposed through a user-local symlink.

## Installer targets

`all` is the default target.

| Command | Action |
| --- | --- |
| `./install.sh` | Install dependencies, both shell setups, and application configs |
| `./install.sh deps` | Install CLI dependencies only |
| `./install.sh shell` | Install and configure both Bash and Zsh |
| `./install.sh bash` | Configure the Bash-to-Zsh hand-off only |
| `./install.sh zsh` | Configure oh-my-zsh, Powerlevel10k, and zsh-autosuggestions |
| `./install.sh config` | Link Neovim, Claude Code keybindings, and optionally Ghostty and herdr configs |
| `./install.sh help` | Show command-line help |

To install user-level files for another account, whose user must be able to read the
checkout:

```sh
./install.sh --user target_user
./install.sh --user target_user config
```

The herdr issue-tree plugin is built and linked separately; see its
[README](../herdr/plugins/issue-tree/README.md).
