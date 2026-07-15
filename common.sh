# Shared shell layer tracked by this repo.
# Keep machine-local environment variables in ~/.bashrc or ~/.zshrc.

remove_path_entry() {
  local target="$1"
  local remaining="${PATH}:"
  local entry
  local result=""

  while [ -n "$remaining" ]; do
    entry="${remaining%%:*}"
    remaining="${remaining#*:}"

    if [ -n "$entry" ] && [ "$entry" != "$target" ]; then
      result="${result:+$result:}$entry"
    fi
  done

  PATH="$result"
}

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

  remove_path_entry "$1"

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
# Mason fills gaps without shadowing tools installed explicitly by install.sh.
add_path --append "$HOME/.local/share/nvim/mason/bin"

# Locale
export LANG=en_US.UTF-8

# Dotfiles scripts
if [ -n "${_dotfiles_dir:-}" ] &&
  [ -x "$_dotfiles_dir/scripts/toggle-theme" ] &&
  ! alias toggletheme >/dev/null 2>&1; then
  alias toggletheme="\"$_dotfiles_dir/scripts/toggle-theme\""
fi
