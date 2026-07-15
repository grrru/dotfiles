#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_HOME="$HOME"
ORIGINAL_SHELL="${SHELL:-}"

command_exists() {
  command -v "$1" &>/dev/null
}

default_shell_name() {
  basename "${TARGET_SHELL:-${SHELL:-}}"
}

zsh_rc_path() {
  if [ "$(id -un)" = "$TARGET_USER" ] && [ -n "${ZDOTDIR:-}" ]; then
    echo "$ZDOTDIR/.zshrc"
  else
    echo "$HOME/.zshrc"
  fi
}

usage() {
  cat <<EOF
Usage: ./install.sh [options] [target]

Options:
  -u, --user USER  Install user-level files for USER instead of the current user

Targets:
  all      Install dependencies, shell setup, configs, and tpm (default)
  deps     Install CLI dependencies only
  shell    Install bash bridge and zsh setup
  bash     Install oh-my-bash setup only
  zsh      Install oh-my-zsh + Powerlevel10k setup only
  config   Link application configs only
  tpm      Install tmux plugin manager only
  help     Show this help
EOF
}

resolve_user_home() {
  local user="$1"
  local home=""

  if command_exists dscl; then
    home="$(dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  fi

  if [ -z "$home" ] && command_exists getent; then
    home="$(getent passwd "$user" | cut -d: -f6)"
  fi

  if [ -z "$home" ] && [ "$user" = "$(id -un)" ]; then
    home="$ORIGINAL_HOME"
  fi

  if [ -z "$home" ]; then
    echo "Could not resolve home directory for user: $user" >&2
    exit 1
  fi

  echo "$home"
}

resolve_user_shell() {
  local user="$1"
  local shell=""

  if command_exists dscl; then
    shell="$(dscl . -read "/Users/$user" UserShell 2>/dev/null | awk '{print $2}')"
  fi

  if [ -z "$shell" ] && command_exists getent; then
    shell="$(getent passwd "$user" | cut -d: -f7)"
  fi

  if [ -z "$shell" ] && [ "$user" = "$(id -un)" ]; then
    shell="$ORIGINAL_SHELL"
  fi

  echo "${shell:-${SHELL:-}}"
}

parse_args() {
  TARGET_USER="$(id -un)"
  target="all"

  while [ "$#" -gt 0 ]; do
    case "$1" in
    -u | --user)
      if [ -z "${2:-}" ]; then
        echo "Missing value for $1" >&2
        usage
        exit 1
      fi
      TARGET_USER="$2"
      shift 2
      ;;
    help | -h | --help)
      target="help"
      shift
      ;;
    *)
      target="$1"
      shift
      ;;
    esac
  done
}

chown_target_path() {
  local path="$1"

  if [ "$(id -un)" = "$TARGET_USER" ] || [ ! -e "$path" ]; then
    return
  fi

  sudo chown -R "$TARGET_USER" "$path"
}

ensure_gruvim_source() {
  if [ ! -d "$DOTFILES_DIR/gruvim" ]; then
    echo "gruvim config not found at $DOTFILES_DIR/gruvim"
    exit 1
  fi
}

NVIM_MIN_VERSION="${NVIM_MIN_VERSION:-0.12.0}"
TREE_SITTER_MIN_VERSION="${TREE_SITTER_MIN_VERSION:-0.26.1}"
FZF_MIN_VERSION="${FZF_MIN_VERSION:-0.48.0}"
TMUX_MIN_VERSION="${TMUX_MIN_VERSION:-3.2}"
# Published in GitHub CLI's official Linux installation guide.
GH_APT_KEYRING_SHA256="${GH_APT_KEYRING_SHA256:-6084d5d7bd8e288441e0e94fc6275570895da18e6751f70f057485dc2d1a811b}"

version_at_least() {
  local current="${1#v}"
  local required="${2#v}"

  awk -v current="$current" -v required="$required" '
    BEGIN {
      split(current, current_parts, ".")
      split(required, required_parts, ".")

      for (i = 1; i <= 3; i++) {
        current_part = current_parts[i] + 0
        required_part = required_parts[i] + 0

        if (current_part > required_part) exit 0
        if (current_part < required_part) exit 1
      }

      exit 0
    }
  '
}

detect_package_manager() {
  local os
  os="$(uname -s)"

  if [ "$os" = "Darwin" ]; then
    if command_exists brew; then
      PACKAGE_MANAGER="brew"
      return
    fi
  else
    if command_exists dnf; then
      PACKAGE_MANAGER="dnf"
      return
    fi

    if command_exists apt-get; then
      PACKAGE_MANAGER="apt"
      return
    fi

    if command_exists brew; then
      PACKAGE_MANAGER="brew"
      return
    fi
  fi

  echo "No supported package manager found (Homebrew, dnf, or apt-get)." >&2
  return 1
}

brew_formula_installed() {
  HOME="$ORIGINAL_HOME" brew list --formula "$1" &>/dev/null
}

install_brew_formula() {
  local formula="$1"

  if brew_formula_installed "$formula"; then
    return
  fi

  HOME="$ORIGINAL_HOME" brew install "$formula"
}

upgrade_brew_formula() {
  local formula="$1"

  if brew_formula_installed "$formula"; then
    HOME="$ORIGINAL_HOME" brew upgrade "$formula"
  else
    HOME="$ORIGINAL_HOME" brew install "$formula"
  fi
}

install_managed_package() {
  local brew_package="$1"
  local dnf_package="$2"
  local apt_package="$3"

  case "$PACKAGE_MANAGER" in
  brew) install_brew_formula "$brew_package" ;;
  dnf) sudo dnf install -y "$dnf_package" ;;
  apt) sudo apt-get install -y "$apt_package" ;;
  esac
}

install_core_dependencies() {
  case "$PACKAGE_MANAGER" in
  brew)
    local brew_packages=(git curl zsh ripgrep make jq python)
    local package

    for package in "${brew_packages[@]}"; do
      install_brew_formula "$package"
    done
    ;;
  dnf)
    sudo dnf install -y \
      ca-certificates curl git zsh ripgrep make tar gzip unzip jq \
      python3 python3-pip
    ;;
  apt)
    sudo apt-get update
    sudo apt-get install -y \
      ca-certificates curl git zsh ripgrep make tar gzip unzip jq \
      python3 python3-pip python3-venv
    ;;
  esac
}

prepend_user_bin_to_path() {
  local user_bin="$HOME/.local/bin"

  mkdir -p "$user_bin"
  chown_target_path "$user_bin"
  move_path_entry "$user_bin" front
}

move_path_entry() {
  local target="$1"
  local position="$2"
  local entry
  local joined
  local -a entries
  local -a kept=()

  IFS=: read -r -a entries <<<"$PATH"
  for entry in "${entries[@]}"; do
    if [ -n "$entry" ] && [ "$entry" != "$target" ]; then
      kept+=("$entry")
    fi
  done

  if [ -d "$target" ] && [ "$position" = front ]; then
    kept=("$target" "${kept[@]}")
  elif [ -d "$target" ]; then
    kept+=("$target")
  fi

  joined="$(
    IFS=:
    echo "${kept[*]}"
  )"
  export PATH="$joined"
  hash -r
}

install_tmux() {
  local current_version=""

  if command_exists tmux; then
    current_version="$(tmux -V | awk '{ print $2 }')"
  fi

  if [ -n "$current_version" ] && version_at_least "$current_version" "$TMUX_MIN_VERSION"; then
    return
  fi

  if [ "$PACKAGE_MANAGER" = "brew" ]; then
    upgrade_brew_formula tmux
  else
    install_managed_package tmux tmux tmux
  fi

  hash -r
  current_version="$(tmux -V 2>/dev/null | awk '{ print $2 }')"
  if [ -z "$current_version" ] || ! version_at_least "$current_version" "$TMUX_MIN_VERSION"; then
    echo "tmux ${current_version:-<missing>} at $(command -v tmux 2>/dev/null || echo '<missing>') remains below $TMUX_MIN_VERSION after $PACKAGE_MANAGER installation." >&2
    return 1
  fi
}

fd_available() {
  command_exists fd && fd --version 2>/dev/null | grep -Eq '^fd(find)? '
}

install_fd() {
  local fd_link
  local fdfind_path

  if fd_available; then
    return
  fi

  install_managed_package fd fd-find fd-find

  if fd_available; then
    return
  fi

  if ! command_exists fdfind; then
    echo "fd-find was installed, but neither fd nor fdfind is available." >&2
    return 1
  fi

  fd_link="$HOME/.local/bin/fd"
  fdfind_path="$(command -v fdfind)"

  if [ -e "$fd_link" ] && [ ! -L "$fd_link" ]; then
    echo "Cannot create $fd_link because a non-symlink file already exists." >&2
    return 1
  fi

  ln -sfn "$fdfind_path" "$fd_link"
}

github_release_json() {
  local repository="$1"
  local release="$2"
  local endpoint
  local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  local curl_args=(
    --fail
    --silent
    --show-error
    --location
    --retry 3
    --header "Accept: application/vnd.github+json"
    --header "X-GitHub-Api-Version: 2022-11-28"
  )

  if [ "$release" = "latest" ]; then
    endpoint="https://api.github.com/repos/$repository/releases/latest"
  else
    endpoint="https://api.github.com/repos/$repository/releases/tags/$release"
  fi

  if [ -n "$token" ]; then
    curl_args+=(--header "Authorization: Bearer $token")
  fi

  curl "${curl_args[@]}" "$endpoint"
}

download_file() {
  local url="$1"
  local destination="$2"

  if command_exists curl; then
    curl --fail --silent --show-error --location --retry 3 \
      --output "$destination" "$url"
  elif command_exists wget; then
    wget --quiet --tries=3 --output-document="$destination" "$url"
  else
    echo "curl or wget is required to download $url." >&2
    return 1
  fi
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual

  if command_exists sha256sum; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command_exists shasum; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else
    echo "No SHA-256 tool found; cannot verify $file." >&2
    return 1
  fi

  if [ "$actual" != "$expected" ]; then
    echo "SHA-256 verification failed for $file." >&2
    return 1
  fi
}

install_user_binary() {
  local source="$1"
  local name="$2"
  local destination="$HOME/.local/bin/$name"

  mkdir -p "$HOME/.local/bin"
  if [ -d "$destination" ] && [ ! -L "$destination" ]; then
    echo "Cannot install $name because $destination is a directory." >&2
    return 1
  fi

  if [ -L "$destination" ]; then
    rm "$destination"
  fi

  install -m 755 "$source" "$destination"
  chown_target_path "$destination"
}

link_user_binary() {
  local target="$1"
  local name="$2"
  local destination="$HOME/.local/bin/$name"

  mkdir -p "$HOME/.local/bin"
  if [ -d "$destination" ] && [ ! -L "$destination" ]; then
    echo "Cannot link $name because $destination is a directory." >&2
    return 1
  fi

  ln -sfn "$target" "$destination"
  if [ "$(id -un)" != "$TARGET_USER" ]; then
    sudo chown -h "$TARGET_USER" "$destination"
  fi
}

download_github_release_asset() {
  local release_json="$1"
  local asset_name="$2"
  local destination="$3"
  local metadata
  local url
  local digest

  if ! metadata="$(
    jq -er --arg name "$asset_name" '
      [.assets[] | select((.name | ascii_downcase) == ($name | ascii_downcase))]
      | if length == 1 then .[0] else error("expected exactly one matching release asset") end
      | [.browser_download_url, .digest]
      | @tsv
    ' <<<"$release_json"
  )"; then
    echo "Could not find a unique release asset named $asset_name." >&2
    return 1
  fi

  IFS=$'\t' read -r url digest <<<"$metadata"
  if [[ "$digest" != sha256:* ]]; then
    echo "GitHub did not provide a SHA-256 digest for $asset_name." >&2
    return 1
  fi

  download_file "$url" "$destination"
  verify_sha256 "$destination" "${digest#sha256:}"
}

linux_release_arch() {
  case "$(uname -m)" in
  x86_64 | amd64) echo "x86_64" ;;
  aarch64 | arm64) echo "arm64" ;;
  *)
    echo "Unsupported Linux architecture: $(uname -m)" >&2
    return 1
    ;;
  esac
}

fzf_release_arch() {
  case "$(uname -m)" in
  x86_64 | amd64) echo "amd64" ;;
  aarch64 | arm64) echo "arm64" ;;
  *)
    echo "Unsupported fzf architecture: $(uname -m)" >&2
    return 1
    ;;
  esac
}

tree_sitter_release_arch() {
  case "$(uname -m)" in
  x86_64 | amd64) echo "x64" ;;
  aarch64 | arm64) echo "arm64" ;;
  *)
    echo "Unsupported Tree-sitter architecture: $(uname -m)" >&2
    return 1
    ;;
  esac
}

zoxide_release_arch() {
  case "$(uname -m)" in
  x86_64 | amd64) echo "x86_64-unknown-linux-musl" ;;
  aarch64 | arm64) echo "aarch64-unknown-linux-musl" ;;
  *)
    echo "Unsupported zoxide architecture: $(uname -m)" >&2
    return 1
    ;;
  esac
}

fzf_version() {
  fzf --version 2>/dev/null | awk 'NR == 1 { print $1 }'
}

install_fzf_release() (
  local release_json
  local release_tag
  local version
  local arch
  local asset_name
  local tmpdir
  local archive

  if ! release_json="$(github_release_json junegunn/fzf latest)"; then
    echo "Failed to fetch the latest fzf release." >&2
    return 1
  fi

  release_tag="$(jq -er '.tag_name' <<<"$release_json")"
  version="${release_tag#v}"
  arch="$(fzf_release_arch)"
  asset_name="fzf-${version}-linux_${arch}.tar.gz"
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-fzf.XXXXXX")"
  archive="$tmpdir/$asset_name"
  trap 'rm -rf "$tmpdir"' EXIT

  download_github_release_asset "$release_json" "$asset_name" "$archive"
  tar -xzf "$archive" -C "$tmpdir" fzf
  install_user_binary "$tmpdir/fzf" fzf
)

install_fzf() {
  local current_version=""

  if command_exists fzf; then
    current_version="$(fzf_version)"
  fi

  if [ -n "$current_version" ] && version_at_least "$current_version" "$FZF_MIN_VERSION"; then
    return
  fi

  case "$PACKAGE_MANAGER" in
  brew)
    upgrade_brew_formula fzf
    ;;
  dnf | apt)
    install_managed_package fzf fzf fzf
    current_version="$(fzf_version 2>/dev/null || true)"
    if [ -z "$current_version" ] || ! version_at_least "$current_version" "$FZF_MIN_VERSION"; then
      install_fzf_release
    fi
    ;;
  esac

  hash -r
}

install_zoxide_release() (
  local release_json
  local release_tag
  local version
  local arch
  local asset_name
  local tmpdir
  local archive

  if ! release_json="$(github_release_json ajeetdsouza/zoxide latest)"; then
    echo "Failed to fetch the latest zoxide release." >&2
    return 1
  fi

  release_tag="$(jq -er '.tag_name' <<<"$release_json")"
  version="${release_tag#v}"
  arch="$(zoxide_release_arch)"
  asset_name="zoxide-${version}-${arch}.tar.gz"
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-zoxide.XXXXXX")"
  archive="$tmpdir/$asset_name"
  trap 'rm -rf "$tmpdir"' EXIT

  download_github_release_asset "$release_json" "$asset_name" "$archive"
  tar -xzf "$archive" -C "$tmpdir" zoxide

  if [ ! -x "$tmpdir/zoxide" ]; then
    echo "The zoxide release did not contain an executable zoxide binary." >&2
    return 1
  fi

  install_user_binary "$tmpdir/zoxide" zoxide
)

install_zoxide() {
  if command_exists zoxide && zoxide --version >/dev/null 2>&1; then
    return
  fi

  case "$PACKAGE_MANAGER" in
  brew) install_brew_formula zoxide ;;
  dnf) install_managed_package zoxide zoxide zoxide ;;
  apt) install_zoxide_release ;;
  esac

  hash -r
}

neovim_version() {
  nvim --version 2>/dev/null | awk 'NR == 1 { sub(/^NVIM v/, ""); print $1 }'
}

neovim_installation_usable() {
  local install_dir="$1"

  [ -x "$install_dir/bin/nvim" ] &&
    [ -f "$install_dir/share/nvim/runtime/filetype.lua" ] &&
    "$install_dir/bin/nvim" --headless -u NONE -i NONE +qa >/dev/null 2>&1
}

install_neovim_release() (
  local release_json
  local arch
  local asset_name
  local tmpdir
  local archive
  local extracted_dir
  local version
  local install_dir

  if ! release_json="$(github_release_json neovim/neovim stable)"; then
    echo "Failed to fetch the stable Neovim release." >&2
    return 1
  fi

  arch="$(linux_release_arch)"
  asset_name="nvim-linux-${arch}.tar.gz"
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-neovim.XXXXXX")"
  archive="$tmpdir/$asset_name"
  extracted_dir="$tmpdir/nvim-linux-${arch}"
  trap 'rm -rf "$tmpdir"' EXIT

  download_github_release_asset "$release_json" "$asset_name" "$archive"
  tar -xzf "$archive" -C "$tmpdir"
  version="$("$extracted_dir/bin/nvim" --version | awk 'NR == 1 { sub(/^NVIM v/, ""); print $1 }')"

  if ! version_at_least "$version" "$NVIM_MIN_VERSION"; then
    echo "Stable Neovim $version is older than required $NVIM_MIN_VERSION." >&2
    return 1
  fi

  install_dir="/opt/nvim-v$version"
  if [ -e "$install_dir" ] && ! neovim_installation_usable "$install_dir"; then
    echo "$install_dir exists but is not a complete Neovim installation." >&2
    return 1
  fi

  if [ ! -e "$install_dir" ]; then
    sudo install -d -m 755 "$install_dir"
    sudo cp -R "$extracted_dir/." "$install_dir/"
    sudo chown -R root:root "$install_dir"
  fi

  if ! neovim_installation_usable "$install_dir"; then
    echo "Neovim was copied to $install_dir but failed its runtime check." >&2
    return 1
  fi

  link_user_binary "$install_dir/bin/nvim" nvim
)

install_neovim() {
  local current_version=""

  if command_exists nvim; then
    current_version="$(neovim_version)"
  fi

  if [ -n "$current_version" ] && version_at_least "$current_version" "$NVIM_MIN_VERSION"; then
    return
  fi

  if [ "$PACKAGE_MANAGER" = "brew" ]; then
    upgrade_brew_formula neovim
  else
    install_neovim_release
  fi

  hash -r
}

tree_sitter_version() {
  tree-sitter --version 2>/dev/null | awk 'NR == 1 { print $2 }'
}

install_tree_sitter_release() (
  local release_json
  local arch
  local asset_name
  local tmpdir
  local archive
  local binary
  local version

  if ! release_json="$(github_release_json tree-sitter/tree-sitter latest)"; then
    echo "Failed to fetch the latest Tree-sitter release." >&2
    return 1
  fi

  arch="$(tree_sitter_release_arch)"
  asset_name="tree-sitter-cli-linux-${arch}.zip"
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tree-sitter.XXXXXX")"
  archive="$tmpdir/$asset_name"
  binary="$tmpdir/tree-sitter"
  trap 'rm -rf "$tmpdir"' EXIT

  download_github_release_asset "$release_json" "$asset_name" "$archive"
  unzip -q "$archive" -d "$tmpdir"

  if [ ! -x "$binary" ]; then
    echo "The Tree-sitter release did not contain an executable tree-sitter binary." >&2
    return 1
  fi

  version="$("$binary" --version | awk 'NR == 1 { print $2 }')"
  if ! version_at_least "$version" "$TREE_SITTER_MIN_VERSION"; then
    echo "Tree-sitter $version is older than required $TREE_SITTER_MIN_VERSION." >&2
    return 1
  fi

  install_user_binary "$binary" tree-sitter
)

install_tree_sitter() {
  local current_version=""

  if command_exists tree-sitter; then
    current_version="$(tree_sitter_version)"
  fi

  if [ -n "$current_version" ] && version_at_least "$current_version" "$TREE_SITTER_MIN_VERSION"; then
    return
  fi

  if [ "$PACKAGE_MANAGER" = "brew" ]; then
    upgrade_brew_formula tree-sitter-cli
  else
    install_tree_sitter_release
  fi

  hash -r
}

gh_binary_supports_state_reason() {
  local binary="$1"
  local fields

  [ -x "$binary" ] || return 1
  fields="$("$binary" issue list --json 2>&1 || true)"
  grep -q '^[[:space:]]*stateReason$' <<<"$fields"
}

gh_supports_state_reason() {
  local binary

  command_exists gh || return 1
  binary="$(command -v gh)"
  gh_binary_supports_state_reason "$binary"
}

gh_apt_source_line() {
  local architecture="$1"

  printf '%s\n' \
    "deb [arch=$architecture signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"
}

configure_gh_apt_repository() (
  local tmpdir
  local keyring
  local architecture

  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-gh.XXXXXX")"
  keyring="$tmpdir/githubcli-archive-keyring.gpg"
  trap 'rm -rf "$tmpdir"' EXIT

  download_file \
    https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    "$keyring"
  verify_sha256 "$keyring" "$GH_APT_KEYRING_SHA256"

  sudo install -d -m 755 /etc/apt/keyrings /etc/apt/sources.list.d
  sudo install -m 644 "$keyring" /etc/apt/keyrings/githubcli-archive-keyring.gpg
  architecture="$(dpkg --print-architecture)"
  gh_apt_source_line "$architecture" |
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
)

install_gh_apt() {
  if [ "${GH_PACKAGE_SOURCE_READY:-0}" != 1 ]; then
    configure_gh_apt_repository
  fi
  sudo apt-get update
  sudo apt-get install -y gh
}

configure_gh_dnf_repository() (
  local tmpdir
  local repo_file

  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-gh.XXXXXX")"
  repo_file="$tmpdir/gh-cli.repo"
  trap 'rm -rf "$tmpdir"' EXIT

  download_file https://cli.github.com/packages/rpm/gh-cli.repo "$repo_file"

  sudo install -d -m 755 /etc/yum.repos.d
  sudo install -m 644 "$repo_file" /etc/yum.repos.d/gh-cli.repo
)

install_gh_dnf() {
  if [ "${GH_PACKAGE_SOURCE_READY:-0}" != 1 ]; then
    configure_gh_dnf_repository
  fi
  sudo dnf install -y gh
}

prepare_gh_package_source() {
  case "$PACKAGE_MANAGER" in
  apt)
    if command_exists curl || command_exists wget; then
      configure_gh_apt_repository
      GH_PACKAGE_SOURCE_READY=1
    elif [ -e /etc/apt/sources.list.d/github-cli.list ]; then
      if [ ! -e /etc/apt/keyrings/githubcli-archive-keyring.gpg ]; then
        echo "Cannot repair github-cli.list before apt-get update without curl, wget, or an existing keyring." >&2
        return 1
      fi

      sudo chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg
      gh_apt_source_line "$(dpkg --print-architecture)" |
        sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      GH_PACKAGE_SOURCE_READY=1
    fi
    ;;
  dnf)
    if command_exists curl || command_exists wget; then
      configure_gh_dnf_repository
      GH_PACKAGE_SOURCE_READY=1
    fi
    ;;
  esac
}

install_gh() {
  local managed_binary=""

  if gh_supports_state_reason; then
    return
  fi

  case "$PACKAGE_MANAGER" in
  brew) upgrade_brew_formula gh ;;
  dnf) install_gh_dnf ;;
  apt) install_gh_apt ;;
  esac

  hash -r
  case "$PACKAGE_MANAGER" in
  brew) managed_binary="$(HOME="$ORIGINAL_HOME" brew --prefix gh)/bin/gh" ;;
  dnf | apt) managed_binary="/usr/bin/gh" ;;
  esac

  if ! gh_supports_state_reason && gh_binary_supports_state_reason "$managed_binary"; then
    link_user_binary "$managed_binary" gh
    hash -r
  fi

  if ! gh_supports_state_reason; then
    echo "The gh selected from PATH ($(command -v gh 2>/dev/null || echo '<missing>')) does not support the stateReason field required by Snacks.gh." >&2
    return 1
  fi
}

install_lazygit_release() (
  local release_json
  local release_tag
  local version
  local arch
  local asset_name
  local tmpdir
  local archive
  local binary

  if ! release_json="$(github_release_json jesseduffield/lazygit latest)"; then
    echo "Failed to fetch the latest Lazygit release." >&2
    return 1
  fi

  release_tag="$(jq -er '.tag_name' <<<"$release_json")"
  version="${release_tag#v}"
  arch="$(linux_release_arch)"
  asset_name="lazygit_${version}_Linux_${arch}.tar.gz"
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-lazygit.XXXXXX")"
  archive="$tmpdir/$asset_name"
  binary="$tmpdir/lazygit"
  trap 'rm -rf "$tmpdir"' EXIT

  download_github_release_asset "$release_json" "$asset_name" "$archive"
  tar -xzf "$archive" -C "$tmpdir" lazygit

  if [ ! -x "$binary" ]; then
    echo "The Lazygit release did not contain an executable lazygit binary." >&2
    return 1
  fi

  install_user_binary "$binary" lazygit
)

install_lazygit() {
  if command_exists lazygit && lazygit --version >/dev/null 2>&1; then
    return
  fi

  if [ "$PACKAGE_MANAGER" = "brew" ]; then
    install_brew_formula lazygit
  else
    install_lazygit_release
  fi

  hash -r
}

verify_dependencies() {
  local commands=(git curl zsh tmux nvim rg fd fzf zoxide make tar unzip jq python3 gh lazygit tree-sitter)
  local command
  local failed=0
  local version

  for command in "${commands[@]}"; do
    if ! command_exists "$command"; then
      echo "Required command is missing after installation: $command" >&2
      failed=1
    fi
  done

  if command_exists tmux; then
    version="$(tmux -V | awk '{ print $2 }')"
    if ! version_at_least "$version" "$TMUX_MIN_VERSION"; then
      echo "tmux $TMUX_MIN_VERSION or newer is required; found $version at $(command -v tmux)." >&2
      failed=1
    fi
  fi

  if command_exists nvim; then
    version="$(neovim_version)"
    if ! version_at_least "$version" "$NVIM_MIN_VERSION"; then
      echo "Neovim $NVIM_MIN_VERSION or newer is required; found $version at $(command -v nvim)." >&2
      failed=1
    fi
  fi

  if command_exists fzf; then
    version="$(fzf_version)"
    if ! version_at_least "$version" "$FZF_MIN_VERSION"; then
      echo "fzf $FZF_MIN_VERSION or newer is required; found $version at $(command -v fzf)." >&2
      failed=1
    fi
  fi

  if command_exists tree-sitter; then
    version="$(tree_sitter_version)"
    if ! version_at_least "$version" "$TREE_SITTER_MIN_VERSION"; then
      echo "Tree-sitter CLI $TREE_SITTER_MIN_VERSION or newer is required; found $version at $(command -v tree-sitter)." >&2
      failed=1
    fi
  fi

  if command_exists zoxide && ! zoxide --version >/dev/null 2>&1; then
    echo "zoxide exists at $(command -v zoxide) but cannot run." >&2
    failed=1
  fi

  if command_exists lazygit && ! lazygit --version >/dev/null 2>&1; then
    echo "lazygit exists at $(command -v lazygit) but cannot run." >&2
    failed=1
  fi

  if ! fd_available; then
    echo "The fd command is missing or is not sharkdp/fd." >&2
    failed=1
  fi

  if ! gh_supports_state_reason; then
    echo "gh at $(command -v gh 2>/dev/null || echo '<missing>') does not expose the stateReason field required by Snacks.gh." >&2
    failed=1
  fi

  return "$failed"
}

run_dependency_step() {
  local label="$1"

  shift
  printf '\n==> %s\n' "$label"
  "$@"
}

install_dependencies() {
  echo "Installing and validating dependencies..."
  detect_package_manager
  echo "Using package manager: $PACKAGE_MANAGER"

  prepend_user_bin_to_path
  move_path_entry "$HOME/.local/share/nvim/mason/bin" end
  run_dependency_step "GitHub CLI package source preflight" prepare_gh_package_source
  run_dependency_step "Base packages ($PACKAGE_MANAGER)" install_core_dependencies
  run_dependency_step "tmux $TMUX_MIN_VERSION+ ($PACKAGE_MANAGER)" install_tmux
  run_dependency_step "fd ($PACKAGE_MANAGER, with Debian command alias)" install_fd
  run_dependency_step "fzf ($PACKAGE_MANAGER, upstream fallback when too old)" install_fzf
  run_dependency_step "zoxide ($PACKAGE_MANAGER)" install_zoxide
  run_dependency_step "Neovim (Homebrew or verified upstream release)" install_neovim
  run_dependency_step "Tree-sitter CLI (Homebrew or verified upstream release)" install_tree_sitter
  run_dependency_step "GitHub CLI (official package source)" install_gh
  run_dependency_step "Lazygit (Homebrew or verified upstream release)" install_lazygit
  run_dependency_step "Dependency verification" verify_dependencies

  printf '\nDependency installation complete.\n'
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

  if ! command_exists git; then
    echo "git is not installed. Skipping oh-my-zsh."
    return
  fi

  echo "Installing oh-my-zsh..."
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  chown_target_path "$HOME/.oh-my-zsh"
}

install_powerlevel10k() {
  local dest="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "oh-my-zsh not installed. Skipping powerlevel10k."
    return
  fi

  if [ -d "$dest" ]; then
    echo "powerlevel10k already installed, skipping."
  else
    echo "Installing powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$dest"
  fi

  # Prompt style/colors live in zsh/p10k.zsh and are linked to ~/.p10k.zsh.
  chown_target_path "$dest"
}

install_zsh_autosuggestions() {
  local dest="$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "oh-my-zsh not installed. Skipping zsh-autosuggestions."
    return
  fi

  if [ -d "$dest" ]; then
    echo "zsh-autosuggestions already installed, skipping."
  else
    echo "Installing zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$dest"
  fi

  chown_target_path "$dest"
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

  if ! command_exists git; then
    echo "git is not installed. Skipping oh-my-bash."
    return
  fi

  echo "Installing oh-my-bash..."
  git clone --depth=1 https://github.com/ohmybash/oh-my-bash.git "$HOME/.oh-my-bash"
  chown_target_path "$HOME/.oh-my-bash"
}

install_oh_my_for_shell() {
  local shell_name="${1:-$(default_shell_name)}"

  case "$shell_name" in
  zsh)
    install_oh_my_zsh
    install_powerlevel10k
    install_zsh_autosuggestions
    ;;
  bash)
    install_oh_my_bash
    ;;
  *)
    echo "Default shell is not bash or zsh. Skipping oh-my shell setup."
    ;;
  esac
}

# Function to create symlinks
link_config() {
  local name="$1"
  local target="$DOTFILES_DIR/$name"
  local dest="$CONFIG_DIR/$name"
  local current_target

  if [ -L "$dest" ]; then
    current_target="$(readlink "$dest")"
    if [ "$current_target" = "$target" ]; then
      echo "Symlink for $name already points to dotfiles, skipping."
    else
      rm "$dest"
      ln -s "$target" "$dest"
      echo "Updated symlink for $name"
    fi
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

configure_bash_common() {
  local shell_rc="$HOME/.bashrc"
  local source_line="source \"$DOTFILES_DIR/bash/bash_config.sh\""

  touch "$shell_rc"
  if grep -Fq "$source_line" "$shell_rc"; then
    echo "bash config already sourced, skipping."
  else
    printf '\n# dotfiles bash config (oh-my-bash + shared shell layer)\n%s\n' "$source_line" >>"$shell_rc"
    echo "Added bash config source to $shell_rc"
  fi
  chown_target_path "$shell_rc"
}

link_p10k_config() {
  local target="$DOTFILES_DIR/zsh/p10k.zsh"
  local dest="$HOME/.p10k.zsh"

  if [ ! -f "$target" ]; then
    echo "p10k config not found at $target, skipping."
    return
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "p10k config already exists at $dest, skipping."
    return
  fi

  ln -s "$target" "$dest"
  echo "Created p10k config symlink."
}

configure_zsh_common() {
  local shell_rc
  local source_line="source \"$DOTFILES_DIR/zsh/zsh_config.sh\""

  shell_rc="$(zsh_rc_path)"

  touch "$shell_rc"
  if grep -Fq "$source_line" "$shell_rc"; then
    echo "zsh config already sourced, skipping."
  else
    printf '\n# dotfiles zsh config (oh-my-zsh + Powerlevel10k + shared shell layer)\n%s\n' "$source_line" >>"$shell_rc"
    echo "Added zsh config source to $shell_rc"
  fi

  link_p10k_config
  chown_target_path "$shell_rc"
}

install_shell() {
  local shell_name="${1:-$(default_shell_name)}"

  install_oh_my_for_shell "$shell_name"
  case "$shell_name" in
  bash) configure_bash_common ;;
  zsh) configure_zsh_common ;;
  esac
}

install_shells() {
  install_shell bash
  install_shell zsh
}

install_configs() {
  mkdir -p "$CONFIG_DIR"
  chown_target_path "$CONFIG_DIR"
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
    chown_target_path "$DOTFILES_DIR/tmux/plugins/tpm"
  else
    echo "tpm already installed, skipping."
    chown_target_path "$DOTFILES_DIR/tmux/plugins/tpm"
  fi
}

install_all() {
  install_dependencies
  install_shells
  install_configs
  install_tpm

  echo "Installation complete!"
  echo "Default Neovim config now points to: gruvim"
}

main() {
  parse_args "$@"

  if [ "$target" = "help" ]; then
    usage
    return
  fi

  if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "User not found: $TARGET_USER" >&2
    return 1
  fi

  TARGET_HOME="$(resolve_user_home "$TARGET_USER")"
  TARGET_SHELL="$(resolve_user_shell "$TARGET_USER")"
  HOME="$TARGET_HOME"
  CONFIG_DIR="$HOME/.config"
  export HOME

  case "$target" in
  all)
    install_all
    ;;
  deps)
    install_dependencies
    ;;
  shell)
    install_shells
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
    return 1
    ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
