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

## Personal shared shell layer
[[ -r "$HOME/.shell_common.sh" ]] && source "$HOME/.shell_common.sh"

## nvm bash completion (nvm.sh itself is loaded in the shared layer; NVM_DIR set there)
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

## Tools (installed by install.sh; guarded so a missing tool is a no-op)
command -v fzf >/dev/null && eval "$(fzf --bash)"

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
