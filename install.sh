#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

# Function to install dependencies
install_dependencies() {
  echo "Checking for dependencies..."

  # TODO: 필요한 패키지 스캔 후 설치하는 방식으로 변경
  if command -v brew &>/dev/null; then
    echo "Using Homebrew to install dependencies..."
    local deps=(lazygit ripgrep fd stylua gh fzf zoxide)
    for dep in "${deps[@]}"; do
      if ! command -v "$dep" &>/dev/null; then
        brew install "$dep"
      fi
    done
  elif command -v pacman &>/dev/null; then
    echo "Detected pacman (Arch Linux). Installing..."
    sudo pacman -S --noconfirm --needed ripgrep fd fzf zoxide github-cli lazygit stylua
  elif command -v dnf &>/dev/null; then
    echo "Detected dnf (Fedora). Installing..."
    sudo dnf copr enable -y atim/lazygit
    sudo dnf install -y ripgrep fd-find fzf zoxide gh lazygit
  elif command -v apt-get &>/dev/null; then
    echo "Detected apt-get (Ubuntu/Debian). Installing..."
    sudo apt-get update
    sudo apt-get install -y ripgrep fd-find fzf zoxide
    echo "Tip: For lazygit, gh, and stylua, follow official manual installation for Debian/Ubuntu."
  else
    echo "No supported package manager found (brew, pacman, dnf, apt-get). Please install dependencies manually."
  fi
}

# Function to create symlinks
link_config() {
  local name="$1"
  local target="$DOTFILES_DIR/$name"
  local dest="$CONFIG_DIR/$name"

  if [ -L "$dest" ]; then
    echo "Symlink for $name already exists, skipping."
  elif [ -d "$dest" ] || [ -f "$dest" ]; then
    echo "Existing config for $name found. Backing up to $dest.bak"
    mv "$dest" "$dest.bak"
    ln -s "$target" "$dest"
    echo "Created symlink for $name"
  else
    ln -s "$target" "$dest"
    echo "Created symlink for $name"
  fi
}

# 1. Install dependencies
install_dependencies

# 2. Create config directory and link configs
mkdir -p "$CONFIG_DIR"
link_config "nvim"
link_config "tmux"

# Link ghostty config only if ghostty is installed
if command -v ghostty &>/dev/null; then
  link_config "ghostty"
fi

# 3. Ensure tpm is installed
if [ ! -d "$DOTFILES_DIR/tmux/plugins/tpm" ]; then
  echo "Installing tpm (Tmux Plugin Manager)..."
  git clone https://github.com/tmux-plugins/tpm "$DOTFILES_DIR/tmux/plugins/tpm"
fi

echo "Installation complete!"
