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

## Deduplicate PATH (catch any duplicates introduced by sourced scripts)
PATH=$(echo "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
export PATH
