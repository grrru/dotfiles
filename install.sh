#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

command_exists() {
  command -v "$1" &>/dev/null
}

default_shell_name() {
  basename "${SHELL:-}"
}

usage() {
  cat <<EOF
Usage: ./install.sh [target]

Targets:
  all      Install dependencies, shell setup, configs, and tpm (default)
  deps     Install CLI dependencies only
  shell    Install oh-my and mise activation for the default shell
  bash     Install oh-my-bash and bash mise activation only
  zsh      Install oh-my-zsh and zsh mise activation only
  config   Link application configs only
  tpm      Install tmux plugin manager only
  help     Show this help
EOF
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
    local deps=(git curl tmux neovim lazygit ripgrep fd gh fzf zoxide make mise)
    for dep in "${deps[@]}"; do
      if ! brew list --formula "$dep" &>/dev/null; then
        brew install "$dep"
      fi
    done
  elif command_exists dnf; then
    echo "Detected dnf (Fedora). Installing..."
    sudo dnf copr enable -y atim/lazygit
    sudo dnf copr enable -y jdxcode/mise
    sudo dnf install -y git curl tmux neovim ripgrep fd-find fzf zoxide gh lazygit make mise
  elif command_exists pacman; then
    echo "Detected pacman (Arch Linux). Installing..."
    sudo pacman -S --noconfirm --needed git curl tmux neovim ripgrep fd fzf zoxide github-cli lazygit make mise
  elif command_exists apt-get; then
    echo "Detected apt-get (Ubuntu/Debian). Installing..."
    sudo apt-get update
    sudo apt-get install -y git curl tmux neovim ripgrep fd-find fzf zoxide make ca-certificates gpg
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

install_oh_my_bash() {
  if [ -d "$HOME/.oh-my-bash" ]; then
    echo "oh-my-bash already installed, skipping."
    return
  fi

  if ! command_exists bash; then
    echo "bash is not installed. Skipping oh-my-bash."
    return
  fi

  if ! command_exists curl; then
    echo "curl is not installed. Skipping oh-my-bash."
    return
  fi

  echo "Installing oh-my-bash..."
  curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | OSH="$HOME/.oh-my-bash" bash -s -- --unattended
}

install_oh_my_for_shell() {
  local shell_name="${1:-$(default_shell_name)}"

  case "$shell_name" in
  zsh)
    install_oh_my_zsh
    ;;
  bash)
    install_oh_my_bash
    ;;
  *)
    echo "Default shell is not bash or zsh. Skipping oh-my shell setup."
    ;;
  esac
}

configure_mise_shell() {
  local shell_name
  local shell_rc
  local shell_rc_dir
  local activation

  shell_name="${1:-$(default_shell_name)}"

  if ! command_exists mise; then
    echo "mise is not installed. Skipping shell activation."
    return
  fi

  case "$shell_name" in
  zsh)
    shell_rc="${ZDOTDIR:-$HOME}/.zshrc"
    activation='eval "$(mise activate zsh)"'
    ;;
  bash)
    shell_rc="$HOME/.bashrc"
    activation='eval "$(mise activate bash)"'
    ;;
  *)
    echo "Default shell is not bash or zsh. Skipping mise shell activation."
    return
    ;;
  esac

  shell_rc_dir="$(dirname "$shell_rc")"
  mkdir -p "$shell_rc_dir"
  touch "$shell_rc"
  if grep -Fq "$activation" "$shell_rc"; then
    echo "mise $shell_name activation already configured, skipping."
  else
    printf '\n# mise\n%s\n' "$activation" >>"$shell_rc"
    echo "Configured mise activation in $shell_rc"
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

install_shell() {
  local shell_name="${1:-$(default_shell_name)}"

  install_oh_my_for_shell "$shell_name"
  configure_mise_shell "$shell_name"
}

install_configs() {
  mkdir -p "$CONFIG_DIR"
  ensure_gruvim_source
  link_app_config "gruvim" "nvim"
  link_config "tmux"

  # Link ghostty config only if ghostty is installed
  if command_exists ghostty; then
    link_config "ghostty"
  fi
}

install_tpm() {
  if [ ! -d "$DOTFILES_DIR/tmux/plugins/tpm" ]; then
    echo "Installing tpm (Tmux Plugin Manager)..."
    git clone https://github.com/tmux-plugins/tpm "$DOTFILES_DIR/tmux/plugins/tpm"
  else
    echo "tpm already installed, skipping."
  fi
}

install_all() {
  install_dependencies
  install_shell
  install_configs
  install_tpm

  echo "Installation complete!"
  echo "Default Neovim config now points to: gruvim"
}

target="${1:-all}"

case "$target" in
all)
  install_all
  ;;
deps)
  install_dependencies
  ;;
shell)
  install_shell
  ;;
bash)
  install_shell bash
  ;;
zsh)
  install_shell zsh
  ;;
config)
  install_configs
  ;;
tpm)
  install_tpm
  ;;
help | -h | --help)
  usage
  ;;
*)
  echo "Unknown target: $target"
  usage
  exit 1
  ;;
esac
