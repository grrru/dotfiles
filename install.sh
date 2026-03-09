#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

# Function to install dependencies
install_dependencies() {
  echo "Checking for dependencies..."

  # 1. Use Homebrew if available (works on both macOS and Linux)
  if command -v brew &> /dev/null; then
    echo "Using Homebrew to install dependencies..."
    local deps=(lazygit ripgrep fd stylua gh fzf zoxide)
    for dep in "${deps[@]}"; do
      if ! command -v "$dep" &> /dev/null; then
        brew install "$dep"
      fi
    done
    return
  fi

  # 2. Native Package Managers for Linux
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          echo "Detected Ubuntu/Debian. Updating and installing..."
          sudo apt-get update
          # Note: fd is 'fd-find' on Ubuntu. lazygit/stylua/gh often need separate repos.
          sudo apt-get install -y ripgrep fd-find fzf zoxide
          echo "Tip: For lazygit and gh, follow official manual installation for Debian/Ubuntu."
          ;;
        arch)
          echo "Detected Arch Linux. Installing..."
          sudo pacman -S --noconfirm ripgrep fd fzf zoxide github-cli lazygit stylua
          ;;
        fedora)
          echo "Detected Fedora. Installing..."
          sudo dnf install -y ripgrep fd-find fzf zoxide gh lazygit
          ;;
        *)
          echo "Unsupported Linux distribution: $ID. Please install dependencies manually."
          ;;
      esac
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Homebrew is required on macOS. Please install it first: https://brew.sh/"
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
if command -v ghostty &> /dev/null; then
  link_config "ghostty"
fi

# 3. Ensure tpm is installed
if [ ! -d "$DOTFILES_DIR/tmux/plugins/tpm" ]; then
  echo "Installing tpm (Tmux Plugin Manager)..."
  git clone https://github.com/tmux-plugins/tpm "$DOTFILES_DIR/tmux/plugins/tpm"
fi

echo "Installation complete!"
