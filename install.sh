#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

command_exists() {
  command -v "$1" &>/dev/null
}

ensure_gruvim_source() {
  if [ ! -d "$DOTFILES_DIR/gruvim" ]; then
    echo "gruvim config not found at $DOTFILES_DIR/gruvim"
    exit 1
  fi
}

# Function to install dependencies
install_dependencies() {
  echo "Checking for dependencies..."

  # TODO: 필요한 패키지 스캔 후 설치하는 방식으로 변경
  if command_exists brew; then
    echo "Using Homebrew to install dependencies..."
    local deps=(git curl zsh tmux neovim lazygit ripgrep fd gh fzf zoxide make mise)
    for dep in "${deps[@]}"; do
      if ! brew list --formula "$dep" &>/dev/null; then
        brew install "$dep"
      fi
    done
  elif command_exists dnf; then
    echo "Detected dnf (Fedora). Installing..."
    sudo dnf copr enable -y atim/lazygit
    sudo dnf copr enable -y jdxcode/mise
    sudo dnf install -y git curl zsh tmux neovim ripgrep fd-find fzf zoxide gh lazygit make mise
  elif command_exists pacman; then
    echo "Detected pacman (Arch Linux). Installing..."
    sudo pacman -S --noconfirm --needed git curl zsh tmux neovim ripgrep fd fzf zoxide github-cli lazygit make mise
  elif command_exists apt-get; then
    echo "Detected apt-get (Ubuntu/Debian). Installing..."
    sudo apt-get update
    sudo apt-get install -y git curl zsh tmux neovim ripgrep fd-find fzf zoxide make ca-certificates gpg
    install_mise_with_apt
    echo "Tip: For lazygit and gh, follow official manual installation for Debian/Ubuntu."
  else
    echo "No supported package manager found (brew, pacman, dnf, apt-get). Please install dependencies manually."
  fi
}

install_mise_with_apt() {
  if command_exists mise; then
    echo "mise already installed, skipping apt setup."
    return
  fi

  sudo install -dm 755 /etc/apt/keyrings
  curl -fSs https://mise.en.dev/gpg-key.pub | sudo tee /etc/apt/keyrings/mise-archive-keyring.asc >/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.asc] https://mise.en.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y mise
}

install_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "oh-my-zsh already installed, skipping."
    return
  fi

  if ! command_exists zsh; then
    echo "zsh is not installed. Skipping oh-my-zsh."
    return
  fi

  if ! command_exists curl; then
    echo "curl is not installed. Skipping oh-my-zsh."
    return
  fi

  echo "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

configure_mise_shell() {
  local zshrc="${ZDOTDIR:-$HOME}/.zshrc"
  local zsh_dir
  local activation='eval "$(mise activate zsh)"'

  if ! command_exists mise; then
    echo "mise is not installed. Skipping shell activation."
    return
  fi

  zsh_dir="$(dirname "$zshrc")"
  mkdir -p "$zsh_dir"
  touch "$zshrc"
  if grep -Fq "$activation" "$zshrc"; then
    echo "mise zsh activation already configured, skipping."
  else
    printf '\n# mise\n%s\n' "$activation" >>"$zshrc"
    echo "Configured mise activation in $zshrc"
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
install_oh_my_zsh

# 2. Create config directory and link configs
mkdir -p "$CONFIG_DIR"
configure_mise_shell
ensure_gruvim_source
link_app_config "gruvim" "nvim"
link_config "tmux"

# Link ghostty config only if ghostty is installed
if command_exists ghostty; then
  link_config "ghostty"
fi

# 3. Ensure tpm is installed
if [ ! -d "$DOTFILES_DIR/tmux/plugins/tpm" ]; then
  echo "Installing tpm (Tmux Plugin Manager)..."
  git clone https://github.com/tmux-plugins/tpm "$DOTFILES_DIR/tmux/plugins/tpm"
fi

echo "Installation complete!"
echo "Default Neovim config now points to: gruvim"
