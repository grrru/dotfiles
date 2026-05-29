## oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

plugins=(
  git
  docker
  docker-compose
)

## powerlevel10k
# Theme selection must happen before oh-my-zsh is sourced.
ZSH_THEME="powerlevel10k/powerlevel10k"

[[ -s "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

## Personal shared shell layer
[[ -r "$HOME/.shell_common.sh" ]] && source "$HOME/.shell_common.sh"

## Deduplicate PATH (zsh built-in unique array)
typeset -U path
