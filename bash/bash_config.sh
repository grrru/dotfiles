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

## Shared shell layer
_bash_config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
_dotfiles_dir="$(cd -- "$_bash_config_dir/.." && pwd)"
source "$_dotfiles_dir/common.sh"
unset _bash_config_dir _dotfiles_dir

## nvm bash completion (when nvm is loaded by machine-local bash config)
[ -n "${NVM_DIR:-}" ] && [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

## Tools (installed by install.sh; guarded so a missing tool is a no-op)
if command -v fzf >/dev/null 2>&1; then
  fzf_init="$(fzf --bash 2>/dev/null)" && eval "$fzf_init"
  unset fzf_init
fi

## Deduplicate PATH (catch any duplicates introduced by sourced scripts)
PATH=$(echo "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
export PATH

## Switch to zsh as the interactive shell (chsh needs root on this host).
# Interactive-only guard so scp/sftp/non-interactive ssh stay on bash.
# To stay in bash temporarily: `exec bash`. To disable: comment this block.
if [[ $- == *i* ]] && command -v zsh >/dev/null 2>&1; then
  export SHELL="$(command -v zsh)"
  exec zsh -l
fi
