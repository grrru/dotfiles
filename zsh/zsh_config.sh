## oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

plugins=(
  git
  docker
  docker-compose
  zsh-autosuggestions
)

## powerlevel10k
# Theme selection must happen before oh-my-zsh is sourced.
ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=246'

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

## Terminal input modes
# A program that exits without restoring the terminal (an SSH session dropped while the
# Mac sleeps, say) leaves mouse reporting and Kitty keyboard flags on, so clicks and keys
# reach the prompt as escape codes such as `9;5u` for Ctrl-C. After each command, turn
# off mouse tracking, focus reports, the Kitty keyboard stack (popping more entries than
# it holds clears it), and modifyOtherKeys. Skipping shells that have not run a command
# keeps startup output-free for Powerlevel10k's instant prompt.
autoload -Uz add-zsh-hook
_input_modes_dirty=0
_input_modes_mark_dirty() { _input_modes_dirty=1 }
_input_modes_reset() {
  (( _input_modes_dirty )) || return 0
  _input_modes_dirty=0
  print -rn -- $'\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[<99u\e[>4m'
}
add-zsh-hook preexec _input_modes_mark_dirty
add-zsh-hook precmd _input_modes_reset

## Deduplicate PATH (zsh built-in unique array)
typeset -U path
