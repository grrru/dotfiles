# Shared shell layer tracked by this repo.
# Keep machine-local environment variables in ~/.bashrc or ~/.zshrc.

add_path() {
  local mode="append"

  case "${1-}" in
  --prepend | -p)
    mode="prepend"
    shift
    ;;
  --append | -a)
    mode="append"
    shift
    ;;
  esac

  [ -n "${1-}" ] || return 0
  [ -d "$1" ] || return 0

  case ":$PATH:" in
  *:"$1":*) return 0 ;;
  esac

  if [ "$mode" = "prepend" ]; then
    PATH="$1${PATH:+:$PATH}"
  else
    PATH="${PATH:+$PATH:}$1"
  fi
  export PATH
}

ecph() {
  printf '%s\n' "$PATH" | tr ':' '\n'
}

# User bin
add_path --prepend "$HOME/bin"
add_path --prepend "$HOME/.local/bin"

# Locale
export LANG=en_US.UTF-8

# Dotfiles scripts
if [ -n "${_dotfiles_dir:-}" ] &&
  [ -x "$_dotfiles_dir/scripts/toggle-theme" ] &&
  ! alias toggletheme >/dev/null 2>&1; then
  alias toggletheme="\"$_dotfiles_dir/scripts/toggle-theme\""
fi
