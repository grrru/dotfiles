#!/bin/sh

set -eu

window_panes=$(tmux display-message -p '#{window_panes}')
if [ "$window_panes" -ne 3 ]; then
  tmux display-message 'M-3 layout requires exactly 3 panes'
  exit 0
fi

session_id=$(tmux display-message -p '#{session_id}')
window_id=$(tmux display-message -p '#{window_id}')
active_pane=$(tmux display-message -p '#{pane_id}')
tmp_name="__three_pane_layout__"
tmp_window=

cleanup() {
  if [ -n "${tmp_window}" ]; then
    tmux kill-window -t "$tmp_window" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

tmp_window=$(tmux new-window -d -P -F '#{window_id}' -t "$session_id:" -n "$tmp_name")
tmp_first_pane=$(tmux list-panes -t "$tmp_window" -F '#{pane_id}')
tmux split-window -d -h -p 36 -t "$tmp_first_pane" >/dev/null
tmux split-window -d -v -p 50 -t "$tmp_first_pane" >/dev/null

layout=$(tmux display-message -p -t "$tmp_window" '#{window_layout}')
tmux select-layout -t "$window_id" "$layout" >/dev/null
tmux select-pane -t "$active_pane" >/dev/null
