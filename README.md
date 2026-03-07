# Dotfiles

Configuration files for Neovim and Tmux.

## Prerequisites

Ensure the following are installed:
- `git`
- `neovim`
- `tmux`

## Installation

Run the following commands to clone the repository and set up symbolic links:

```bash
git clone https://github.com/your-username/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

## Structure

- `nvim/`: Neovim configuration (LazyVim based). Linked to `~/.config/nvim`.
- `tmux/`: Tmux configuration. Linked to `~/.config/tmux`.
- `install.sh`: Automation script for symlinking and installing TPM.

## Post-Installation

### Tmux
1. Start `tmux`.
2. Press `prefix` + `I` (default prefix is `Ctrl+b`) to fetch and install plugins via TPM.

### Neovim
1. Start `nvim`.
2. `lazy.nvim` will automatically download and install configured plugins on the first run.

## Management

All configuration changes should be made within the `~/dotfiles` directory. Use standard Git workflow to track and sync changes:

```bash
cd ~/dotfiles
git add .
git commit -m "Update config"
git push
```
