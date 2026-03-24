#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

select_neovim_distribution() {
  local choice

  echo "Select Neovim distribution:"
  echo "1) LazyVim"
  echo "2) kickstart (not a distribution)"

  while true; do
    read -r -p "Enter choice [1-2]: " choice
    choice="${choice:-1}"

    case "$choice" in
    1)
      echo "Selected: LazyVim"
      NVIM_CONFIG_SOURCE="LazyVim"
      NVIM_DISTRIBUTION_NAME="LazyVim"
      return
      ;;
    2)
      echo "Selected: kickstart"
      NVIM_CONFIG_SOURCE="kickstart"
      NVIM_DISTRIBUTION_NAME="kickstart"
      return
      ;;
    *)
      echo "Invalid choice. Please enter 1 or 2 ."
      ;;
    esac
  done
}

ensure_config_directory() {
  local dest_dir="$1"
  local display_name="$2"
  local setup_hint="$3"

  if [ -d "$dest_dir" ]; then
    return
  fi

  echo "$display_name config not found at $dest_dir"
  echo "Please prepare it first, for example:"
  echo "  $setup_hint"
  exit 1
}

ensure_neovim_distribution_source() {
  case "$NVIM_CONFIG_SOURCE" in
  LazyVim)
    if [ ! -d "$DOTFILES_DIR/LazyVim" ]; then
      echo "LazyVim config not found at $DOTFILES_DIR/LazyVim"
      exit 1
    fi
    ;;
  nvchad)
    ensure_config_directory "$DOTFILES_DIR/nvchad" "NvChad" "git clone https://github.com/NvChad/starter \"$DOTFILES_DIR/nvchad\""
    ;;
  kickstart)
    ensure_config_directory "$DOTFILES_DIR/kickstart" "kickstart.nvim" "git clone https://github.com/nvim-lua/kickstart.nvim.git \"$DOTFILES_DIR/kickstart\""
    ;;
  *)
    echo "Unsupported Neovim distribution source: $NVIM_CONFIG_SOURCE"
    exit 1
    ;;
  esac
}

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

link_app_config() {
  local source_name="$1"
  local app_name="$2"
  local target="$DOTFILES_DIR/$source_name"
  local dest="$CONFIG_DIR/$app_name"
  local current_target

  if [ -L "$dest" ]; then
    current_target="$(readlink "$dest")"
    if [ "$current_target" = "$target" ]; then
      echo "Symlink for $app_name already points to $source_name, skipping."
    else
      rm "$dest"
      ln -s "$target" "$dest"
      echo "Updated symlink for $app_name -> $source_name"
    fi
  elif [ -d "$dest" ] || [ -f "$dest" ]; then
    echo "Existing config for $app_name found. Backing up to $dest.bak"
    mv "$dest" "$dest.bak"
    ln -s "$target" "$dest"
    echo "Created symlink for $app_name -> $source_name"
  else
    ln -s "$target" "$dest"
    echo "Created symlink for $app_name -> $source_name"
  fi
}

# 1. Install dependencies
install_dependencies

# 2. Create config directory and link configs
mkdir -p "$CONFIG_DIR"
select_neovim_distribution
ensure_neovim_distribution_source
link_app_config "$NVIM_CONFIG_SOURCE" "nvim"
link_config "tmux"

if [ -d "$DOTFILES_DIR/kickstart" ]; then
  link_app_config "kickstart" "kickstart"
fi

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
echo "Default Neovim config now points to: $NVIM_DISTRIBUTION_NAME"
echo "You can also test kickstart with: NVIM_APPNAME=kickstart nvim"
