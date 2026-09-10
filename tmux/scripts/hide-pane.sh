#!/bin/sh
# Hide a pane by parking it in a detached "_hidden" session, and bring it back.
#
#   hide-pane.sh toggle [pane]   restore the most recently hidden pane of the pane's
#                                window if there is one, otherwise hide the pane
#   hide-pane.sh hide [pane]     park the pane (default: active pane)
#   hide-pane.sh unhide [pane]   restore the most recently hidden pane of the pane's
#                                window; falls back to joining it below the pane
#   hide-pane.sh list [pane]     print the hidden pane ids of the pane's window
#
# Pass the pane explicitly (e.g. "#{pane_id}" from a key binding): run-shell does not
# tell child tmux commands which pane they were invoked from.
#
# tmux has no real hidden pane; the maintainer's recommended workaround is to move
# the pane to another session. Hidden pane ids are remembered per window in the
# @hidden_panes user option, and the window layout at hide time in @hidden_layout_<id>,
# so restoring puts every pane back exactly where it was.

set -eu

hidden_session="_hidden"
action=${1:-toggle}
arg=${2:-}

pane=${arg:-$(tmux display-message -p '#{pane_id}')}
window_id=$(tmux display-message -p -t "$pane" '#{window_id}')

hidden_panes() {
  tmux show-options -wqv -t "$window_id" @hidden_panes 2>/dev/null || true
}

set_hidden_panes() {
  if [ -z "$1" ]; then
    tmux set-option -wq -t "$window_id" -u @hidden_panes
  else
    tmux set-option -wq -t "$window_id" @hidden_panes "$1"
  fi
}

layout_option() {
  printf '@hidden_layout_%s' "${1#%}"
}

pane_exists() {
  tmux list-panes -a -F '#{pane_id}' | grep -qx "$1"
}

window_pane_ids() {
  tmux list-panes -t "$window_id" -F '#{pane_id}'
}

# Pane ids in the order the layout string lists them (leaf cells end with ",<id>").
layout_pane_ids() {
  printf '%s\n' "$1" | tr '{}[]' ',,,,' | tr ',' '\n' |
    awk 'prev ~ /^[0-9]+$/ && prev2 ~ /^[0-9]+$/ && prev3 ~ /^[0-9]+x[0-9]+$/ && $0 ~ /^[0-9]+$/ { print "%" $0 }
         { prev3 = prev2; prev2 = prev; prev = $0 }'
}

# Apply a saved layout and swap panes so each id lands in the cell it came from.
restore_layout() {
  layout=$1
  expected=$(layout_pane_ids "$layout")
  if [ "$(printf '%s\n' "$expected" | sort)" != "$(window_pane_ids | sort)" ]; then
    return 1
  fi
  tmux select-layout -t "$window_id" "$layout" >/dev/null
  i=1
  for want in $expected; do
    have=$(window_pane_ids | sed -n "${i}p")
    if [ "$have" != "$want" ]; then
      tmux swap-pane -d -s "$have" -t "$want"
    fi
    i=$((i + 1))
  done
}

do_hide() {
  window_panes=$(tmux display-message -p -t "$window_id" '#{window_panes}')
  if [ "$window_panes" -lt 2 ]; then
    tmux display-message 'cannot hide the only pane in the window'
    return 0
  fi
  layout=$(tmux display-message -p -t "$window_id" '#{window_layout}')

  placeholder=
  if ! tmux has-session -t "=$hidden_session" 2>/dev/null; then
    placeholder=$(tmux new-session -d -P -F '#{pane_id}' -s "$hidden_session")
  fi
  tmux break-pane -d -s "$pane" -t "$hidden_session:"
  if [ -n "$placeholder" ]; then
    tmux kill-pane -t "$placeholder" 2>/dev/null || true
  fi

  current=$(hidden_panes)
  set_hidden_panes "${current:+$current }$pane"
  tmux set-option -wq -t "$window_id" "$(layout_option "$pane")" "$layout"
}

do_unhide() {
  hidden=
  rest=
  # Take the most recently hidden pane that is still alive; drop stale ids.
  for candidate in $(hidden_panes); do
    if pane_exists "$candidate"; then
      if [ -n "$hidden" ]; then
        rest="${rest:+$rest }$hidden"
      fi
      hidden=$candidate
    else
      tmux set-option -wq -t "$window_id" -u "$(layout_option "$candidate")"
    fi
  done
  set_hidden_panes "$rest"

  if [ -z "$hidden" ]; then
    tmux display-message 'no hidden pane for this window'
    return 0
  fi
  layout=$(tmux show-options -wqv -t "$window_id" "$(layout_option "$hidden")" 2>/dev/null || true)
  tmux set-option -wq -t "$window_id" -u "$(layout_option "$hidden")"

  tmux join-pane -d -v -s "$hidden" -t "$pane"
  if [ -n "$layout" ]; then
    restore_layout "$layout" || true
  fi
  tmux select-pane -t "$pane"
}

case "$action" in
toggle)
  if [ -n "$(hidden_panes)" ]; then
    do_unhide
  else
    do_hide
  fi
  ;;
hide) do_hide ;;
unhide) do_unhide ;;
list) hidden_panes ;;
*)
  tmux display-message "hide-pane.sh: unknown action '$action' (toggle|hide|unhide|list) [pane]"
  ;;
esac
