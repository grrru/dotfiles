# Personal shared shell layer template.
# Copy to ~/.shell_common.sh and fill in machine-specific values.
# This file is safe to track; ~/.shell_common.sh is intentionally untracked.

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

# Secrets and machine-local env belong here, not in git.
# export SOME_API_TOKEN="changeme"

# Tool examples
# export ANDROID_HOME="$HOME/Library/Android/sdk"
# add_path "$ANDROID_HOME/emulator"
# add_path "$ANDROID_HOME/platform-tools"
