## oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

plugins=(
  git
  docker
  docker-compose
  # zsh-autosuggestions
)

## powerlevel10k
# Theme selection must happen before oh-my-zsh is sourced.
ZSH_THEME="powerlevel10k/powerlevel10k"

[[ -s "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

## Shared shell layer
_zsh_config_file="${funcsourcetrace[1]%:*}"
if [ -z "$_zsh_config_file" ] || [ "$_zsh_config_file" = "zsh" ]; then
  _zsh_config_file="$0"
fi
_zsh_config_dir="$(cd -- "$(dirname -- "$_zsh_config_file")" && pwd)"
_dotfiles_dir="$(cd -- "$_zsh_config_dir/.." && pwd)"
source "$_dotfiles_dir/common.sh"
unset _zsh_config_file _zsh_config_dir _dotfiles_dir

## Tools (installed by install.sh; guarded so a missing tool is a no-op)
if command -v fzf >/dev/null 2>&1; then
  fzf_init="$(fzf --zsh 2>/dev/null)" && eval "$fzf_init"
  unset fzf_init
fi

## Deduplicate PATH (zsh built-in unique array)
typeset -U path
