## PATH helper — dedup-safe add
add_path_bash() {
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

  [[ -z "${1-}" ]] && return 0
  local p="$1"
  [[ -d "$p" ]] || return 0

  case ":$PATH:" in
  *:"$p":*) return 0 ;;
  esac

  if [[ "$mode" == "prepend" ]]; then
    export PATH="$p${PATH:+:$PATH}"
  else
    export PATH="${PATH:+$PATH:}$p"
  fi
}

## oh-my-bash
export OSH="$HOME/.oh-my-bash"

OSH_THEME="robbyrussell"

completions=(
  git
  composer
  ssh
)
aliases=(
  general
)
plugins=(
  git
  bashmarks
)

[[ -s "$OSH/oh-my-bash.sh" ]] && source "$OSH/oh-my-bash.sh"

## Deduplicate PATH (catch any duplicates introduced by sourced scripts)
PATH=$(echo "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
export PATH
