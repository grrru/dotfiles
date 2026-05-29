## PATH helper — dedup-safe add
add_path_zsh() {
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

## oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

# powerlevel10k: install.sh clones it into $ZSH/custom/themes/powerlevel10k.
# The prompt config ~/.p10k.zsh is NOT tracked in dotfiles — run `p10k configure`
# on each machine to generate it (p10k also auto-runs the wizard on first launch).
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
)

[[ -s "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

## Deduplicate PATH (zsh built-in unique array)
typeset -U path
