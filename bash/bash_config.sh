_bash_config_dir="$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
_dotfiles_dir="$(builtin cd -- "$_bash_config_dir/.." && pwd)"

## Switch to zsh as the interactive shell (chsh needs root on this host).
# Interactive-only guard so scp/sftp/non-interactive ssh stay on bash. A bash
# started from zsh, where SHELL already names zsh, stays bash, so `bash` or
# `exec bash` gives a temporary bash session. To disable: comment this block.
if [[ $- == *i* ]] &&
  [[ ${SHELL##*/} != zsh ]] &&
  command -v zsh >/dev/null 2>&1 &&
  [ -r "$HOME/.zshrc" ] &&
  grep -Fq "$_dotfiles_dir/zsh/zsh_config.sh" "$HOME/.zshrc"; then
  export SHELL="$(command -v zsh)"
  exec zsh -l
fi

## Shared shell layer
source "$_dotfiles_dir/common.sh"

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

unset _bash_config_dir _dotfiles_dir
