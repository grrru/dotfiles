#!/usr/bin/env bash
#
# Live tests for pane-stack against a private herdr server. The server gets its own
# config, state, and socket in a temporary directory and every HERDR_* variable is
# dropped first, so the herdr session this may run inside is never touched. The plugin
# is linked into that server, so its event hooks run throughout. Build the plugin first
# (./install.sh --build).
#
#   HERDR  herdr binary (default: herdr on PATH)

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
herdr_bin=$(command -v "${HERDR:-herdr}") || {
  echo "live: herdr not found" >&2
  exit 1
}
command -v jq >/dev/null || {
  echo "live: jq not found" >&2
  exit 1
}
[[ -x $root/pane-stack ]] || {
  echo "live: no $root/pane-stack; build it with ./install.sh --build" >&2
  exit 1
}

for v in $(env | sed -n 's/^\(HERDR_[A-Z_]*\)=.*/\1/p'); do unset "$v"; done
# The socket path has to fit in sockaddr_un, so the directory stays short.
tmp=$(mktemp -d /tmp/pane-stack.XXXXXX)
export XDG_CONFIG_HOME=$tmp/config XDG_STATE_HOME=$tmp/state XDG_DATA_HOME=$tmp/data XDG_CACHE_HOME=$tmp/cache
export HERDR_CONFIG_PATH=$tmp/config/herdr/config.toml
export HERDR_SOCKET_PATH=$tmp/config/herdr/herdr.sock
# The directory herdr gives the plugin, shared with the hooks herdr runs.
state=$XDG_STATE_HOME/herdr/plugins/dotfiles.pane-stack
mkdir -p "$tmp/config/herdr" "$tmp/state"
: >"$HERDR_CONFIG_PATH"

h() { "$herdr_bin" "$@"; }

server_pid=""
start_server() {
  local i
  "$herdr_bin" server >>"$tmp/server.log" 2>&1 &
  server_pid=$!
  for ((i = 0; i < 40; i++)); do
    if h status server 2>/dev/null | grep -q 'status: running'; then break; fi
    sleep 0.25
  done
  [[ $(h status server | sed -n 's/^ *socket: //p') == "$HERDR_SOCKET_PATH" ]] || {
    echo "live: private server did not start on $HERDR_SOCKET_PATH" >&2
    exit 1
  }
}
stop_server() {
  [[ -n $server_pid ]] || return 0
  h server stop >/dev/null 2>&1 || kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  server_pid=""
}
tmux_server=""
cleanup() {
  if [[ -n $tmux_server ]]; then env -u TMUX tmux -S "$tmux_server" kill-server 2>/dev/null || true; fi
  stop_server
  rm -rf "$tmp"
}
trap cleanup EXIT

failures=0
check() {
  local name=$1
  shift
  if "$@"; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    failures=$((failures + 1))
  fi
}
eq() {
  [[ $1 == "$2" ]] && return 0
  printf '     expected [%s]\n     got      [%s]\n' "$2" "$1"
  return 1
}
# wait_for <command...>: hooks run asynchronously, so poll for up to 15 seconds.
wait_for() {
  local i
  for ((i = 0; i < 60; i++)); do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep 0.25
  done
  return 1
}

# run <pane> <command>: run pane-stack the way a plugin action would; sets $rc.
run() {
  local pane=$1
  shift
  rc=0
  HERDR_BIN_PATH=$herdr_bin HERDR_PANE_ID=$pane PANE_STACK_NOTIFY=0 \
    HERDR_PLUGIN_STATE_DIR=$state "$root/pane-stack" "$@" 2>"$tmp/err" || rc=$?
}

rect_of() {
  h pane layout --pane "$1" 2>/dev/null | jq -r --arg id "$1" \
    '.result.layout.panes[] | select(.pane_id == $id) | "\(.rect.x),\(.rect.y),\(.rect.width),\(.rect.height)"'
}
tab_of() { h pane get "$1" | jq -r '.result.pane.tab_id'; }
token() { h pane get "$1" | jq -r --arg k "$2" '.result.pane.tokens[$k] // empty'; }
title() { h pane get "$1" | jq -r '.result.pane.title // empty'; }
focused() { h api snapshot | jq -r '.result.snapshot.focused_pane_id'; }
exists() { h pane get "$1" >/dev/null 2>&1; }
gone() { ! exists "$1"; }
shell_pid() { h pane process-info --pane "$1" | jq -r '.result.process_info.shell_pid'; }
pids() { for p in "$@"; do shell_pid "$p"; done | tr '\n' ' '; }
rects() { for p in "$@"; do rect_of "$p"; done | tr '\n' ' '; }
park_tab() {
  h tab list --workspace "$ws" |
    jq -r '[.result.tabs[] | select(.["label"] == "⧉ pane-stack") | .tab_id] | first // empty'
}
stack_panes() {
  h pane list | jq -r --arg g "$1" \
    '[.result.panes[] | select(.tokens.ps_stack == $g)] | sort_by(.tokens.ps_order | tonumber)[] | .pane_id' |
    tr '\n' ' '
}
stack_size() { stack_panes "$1" | wc -w | tr -d ' '; }
count_in_tab() {
  h pane list --workspace "$ws" | jq --arg t "$1" '[.result.panes[] | select(.tab_id == $t)] | length'
}
in_slot() { [[ $(rect_of "$1") == "$2" && $(tab_of "$1") == "$3" ]]; }
# Conditions for wait_for, evaluated afresh on every poll.
unstacked() { [[ -z $(token "$1" ps_stack) ]]; }
stack_is() { [[ $(stack_panes "$1") == "$2" ]]; }
titled() { [[ -n $(title "$1") ]]; }
title_is() { [[ $(title "$1") == "$2" ]]; }
moved_from() { [[ $(rect_of "$1") != "$2" ]]; }
unparked_alone() { exists "$1" && [[ $(tab_of "$1") != "$(park_tab)" && $(count_in_tab "$(tab_of "$1")") == 1 ]]; }
grew() { (($(stack_size "$1") > $2)); }
type_exit() {
  h pane send-text "$1" 'exit' >/dev/null
  h pane send-keys "$1" enter >/dev/null
}
split() { h pane split "$1" --direction "$2" --ratio "$3" --no-focus | jq -r '.result.pane.pane_id'; }
# new_workspace: a focused workspace with one pane, $first.
new_workspace() {
  ws=$(h workspace create --label live --cwd /tmp --focus | jq -r '.result.workspace.workspace_id')
  first=$(h pane list --workspace "$ws" | jq -r '.result.panes[0].pane_id')
}
# l_c_m: L | (C / M) with uneven ratios, the shape most sections start from.
l_c_m() {
  new_workspace
  L=$first
  C=$(split "$L" right 0.6)
  M=$(split "$C" down 0.3)
  main_tab=$(tab_of "$L")
}

start_server
h plugin link "$root" >/dev/null

echo "# new"
l_c_m
slot=$(rect_of "$M")
around=$(rects "$L" "$C")
run "$M" new
check "new exits 0" eq "$rc" 0
n1=$(focused)
check "focus moves to the new terminal" test "$n1" != "$M"
check "new terminal fills the slot" eq "$(rect_of "$n1")" "$slot"
check "other panes keep their rectangles" eq "$(rects "$L" "$C")" "$around"
check "old terminal is parked" eq "$(tab_of "$M")" "$(park_tab)"
G=$(token "$M" ps_stack)
check "both terminals are in one stack" eq "$(stack_panes "$G")" "$M $n1 "
check "border title lists the stack" eq "$(title "$n1" | sed 's/:[^] ]*/:x/g')" "⧉ 1:x [2:x]"
check "the new terminal starts in the same directory" eq "$(h pane get "$n1" | jq -r '.result.pane.cwd')" /tmp
for _ in 1 2 3; do run "$(focused)" new; done
read -r -a members <<<"$(stack_panes "$G")"
check "four more news make five members" eq "${#members[@]}" 5
check "four terminals wait in the parking tab" eq "$(count_in_tab "$(park_tab)")" 4
check "parked panes keep a usable size" eq "$(h pane layout --pane "$M" |
  jq '[.result.layout.panes[].rect] | (map(.width) | min) >= 20 and (map(.height) | min) >= 8')" true
check "the slot keeps its rectangle" eq "$(rect_of "$(focused)")" "$slot"

echo "# next / prev"
before=$(pids "${members[@]}")
seen="" all_in_slot=true
for _ in 1 2 3 4 5; do
  run "$(focused)" next
  v=$(focused)
  seen+="$v "
  in_slot "$v" "$slot" "$main_tab" || all_in_slot=false
done
check "next walks the stack in order and wraps" eq "$seen" "${members[0]} ${members[1]} ${members[2]} ${members[3]} ${members[4]} "
check "each switched-in terminal fills the slot" eq "$all_in_slot" true
check "other panes never move" eq "$(rects "$L" "$C")" "$around"
check "main tab keeps three panes" eq "$(count_in_tab "$main_tab")" 3
start=${EPOCHREALTIME:-}
run "$(focused)" prev
[[ -z $start ]] || echo "     one switch in a stack of five: $(awk -v a="$start" -v b="$EPOCHREALTIME" 'BEGIN { printf "%d", (b - a) * 1000 }') ms"
run "$(focused)" prev
check "prev walks backwards" eq "$(focused)" "${members[2]}"
check "title brackets the current terminal" eq "$(title "${members[2]}" | grep -o '\[3:' || true)" "[3:"
check "processes survive switching" eq "$(pids "${members[@]}")" "$before"

echo "# refusals"
run "$L" next
check "a pane without a stack is refused" eq "$rc" 1
notification_accepted() {
  "$herdr_bin" notification show "pane-stack live" --body "refusal" --sound none >/dev/null
}
check "herdr accepts the refusal notification" notification_accepted
run "${members[0]}" next
check "a parked pane acts on its stack's shown terminal" eq "$rc $(focused) $(rect_of "$(focused)")" "0 ${members[3]} $slot"
run "$(focused)" prev
v=$(focused)
h pane zoom --pane "$v" --on >/dev/null
run "$v" next
check "a zoomed tab is refused" eq "$rc" 1
h pane zoom --pane "$v" --off >/dev/null
check "refusals change nothing" eq "$(focused) $(rect_of "$v") $(rects "$L" "$C")" "$v $slot $around"

echo "# concurrency"
v=$(focused)
workers=()
for i in 1 2; do
  HERDR_BIN_PATH=$herdr_bin HERDR_PANE_ID=$v PANE_STACK_NOTIFY=0 HERDR_PLUGIN_STATE_DIR=$state \
    "$root/pane-stack" next 2>"$tmp/err$i" &
  workers+=($!)
done
# Only the workers: a bare wait would also wait for the private server.
for pid in "${workers[@]}"; do wait "$pid" || true; done
check "parallel runs leave one terminal in the slot" eq "$(count_in_tab "$main_tab")" 3
check "parallel runs keep every terminal" eq "$(stack_size "$G")" 5
check "the slot keeps its rectangle after parallel runs" eq "$(rect_of "$(focused)")" "$slot"

echo "# close"
v=$(focused)
read -r -a order <<<"$(stack_panes "$G")"
for ((i = 0; i < ${#order[@]}; i++)); do [[ ${order[i]} != "$v" ]] || nxt=${order[$(((i + 1) % ${#order[@]}))]}; done
run "$v" close
sleep 1.5 # the close fires the pane.closed hook too
check "close exits 0" eq "$rc" 0
check "close removes the terminal" gone "$v"
check "close advances exactly one terminal" eq "$(focused) $(rect_of "$nxt")" "$nxt $slot"
check "the stack shrinks to four" eq "$(stack_size "$G")" 4
for _ in 1 2 3; do run "$(focused)" close; done
sleep 1.5
last=$(focused)
check "closing down to one terminal dissolves the stack" eq "$(token "$last" ps_stack)|$(title "$last")" "|"
check "the parking tab closes when empty" eq "$(park_tab)" ""
check "the last terminal keeps the slot" eq "$(rect_of "$last")" "$slot"
run "$last" close
check "close refuses the last terminal" eq "$rc" 1
check "the last terminal stays open" exists "$last"
check "other panes still never move" eq "$(rects "$L" "$C")" "$around"

echo "# exit in the shown shell: slot is a second child beside one pane"
l_c_m
slot=$(rect_of "$M")
around=$(rects "$L" "$C")
keep=$(pids "$L" "$C")
run "$M" new
shown=$(focused)
type_exit "$shown"
check "the shown shell exits" wait_for gone "$shown"
check "the parked terminal comes back into the slot" wait_for in_slot "$M" "$slot" "$main_tab"
check "the panes beside it are untouched" eq "$(rects "$L" "$C") $(pids "$L" "$C")" "$around $keep"
check "a lone remaining terminal leaves the stack" wait_for unstacked "$M"

echo "# pane close of the shown terminal: slot is a first child beside two panes"
l_c_m
slot=$(rect_of "$L")
around=$(rects "$C" "$M")
keep=$(pids "$L" "$C" "$M")
run "$L" new
n1=$(focused)
run "$n1" new
n2=$(focused)
h pane close "$n2" >/dev/null
check "the next terminal comes back into the slot" wait_for in_slot "$L" "$slot" "$main_tab"
check "the two panes beside it are rebuilt as they were" eq "$(rects "$C" "$M")" "$around"
check "processes survive the rebuild" eq "$(pids "$L" "$C" "$M")" "$keep"
check "no pane is left in the holding tab" eq "$(h tab list --workspace "$ws" | jq '[.result.tabs[] | select(.["label"] | test("정리"))] | length')" 0
check "the stack keeps its other terminal" eq "$(stack_panes "$(token "$L" ps_stack)")" "$L $n1 "
run "$L" next
check "switching still works after the rebuild" eq "$(focused) $(rect_of "$n1")" "$n1 $slot"

echo "# exit beside a three-pane subtree"
new_workspace
A=$first
R=$(split "$A" right 0.55)
B=$(split "$A" down 0.4)
C3=$(split "$B" right 0.5)
main_tab=$(tab_of "$A")
slot=$(rect_of "$R")
around=$(rects "$A" "$B" "$C3")
keep=$(pids "$A" "$B" "$C3")
run "$R" new
shown=$(focused)
type_exit "$shown"
check "the parked terminal comes back beside three panes" wait_for in_slot "$R" "$slot" "$main_tab"
check "the three panes are rebuilt as they were" eq "$(rects "$A" "$B" "$C3") $(pids "$A" "$B" "$C3")" "$around $keep"

echo "# the panes beside the slot change after the last action"
l_c_m
slot=$(rect_of "$M")
run "$M" new
shown=$(focused)
C2=$(split "$C" down 0.5)
sleep 1 # the pane.created hook saves the new surroundings
around=$(rects "$L" "$C" "$C2")
type_exit "$shown"
check "the slot comes back in its place" wait_for in_slot "$M" "$slot" "$main_tab"
check "the reshaped panes beside it stay as they are" eq "$(rects "$L" "$C" "$C2")" "$around"

echo "# a parked terminal or an unrelated pane exits"
l_c_m
slot=$(rect_of "$M")
run "$M" new
n1=$(focused)
run "$n1" new
n2=$(focused)
G=$(token "$M" ps_stack)
type_exit "$M"
check "a parked terminal that exits leaves the stack" wait_for stack_is "$G" "$n1 $n2 "
check "the slot is untouched" eq "$(rect_of "$n2") $(focused)" "$slot $n2"
check "the titles count two terminals" wait_for title_is "$n2" "⧉ 1:zsh [2:zsh]"
type_exit "$L"
check "an unrelated pane exits" wait_for gone "$L"
wait_for moved_from "$n2" "$slot" || true
slot=$(rect_of "$n2")
sleep 1
type_exit "$n2"
check "after the tab was reshaped, exit still refills the slot" wait_for in_slot "$n1" "$slot" "$main_tab"

echo "# the slot is alone in its tab"
new_workspace
S=$first
run "$S" new
shown=$(focused)
type_exit "$shown"
check "the parked terminal reopens alone in a tab of its own" wait_for unparked_alone "$S"

echo "# a layout preset reshapes the tab, then the shown shell exits"
layout_sh=${PANE_LAYOUT_SH:-$root/../../scripts/pane-layout.sh}
if [[ -f $layout_sh ]]; then
  for round in 1 2 3; do
    l_c_m
    run "$M" new
    shown=$(focused)
    # The preset moves every pane through a scratch tab: a burst of pane.moved hooks.
    HERDR_BIN_PATH=$herdr_bin HERDR_ACTIVE_PANE_ID=$shown sh "$layout_sh" three 30 >/dev/null
    sleep 2
    slot=$(rect_of "$shown")
    around=$(rects "$L" "$C")
    type_exit "$shown"
    check "after the preset (round $round) the slot comes back where it was" wait_for in_slot "$M" "$slot" "$main_tab"
    check "and the preset's other panes stay (round $round)" eq "$(rects "$L" "$C")" "$around"
  done
else
  echo "     skipped: no pane-layout.sh at $layout_sh"
fi

echo "# closing the tab or the workspace that holds a slot"
since=$(($(date +%s) * 1000))
l_c_m
run "$M" new
h tab close "$main_tab" >/dev/null
sleep 2
check "closing the tab keeps the parked terminal parked" eq "$(tab_of "$M")" "$(park_tab)"
check "and opens no other tab" eq "$(h tab list --workspace "$ws" | jq '.result.tabs | length')" 1
l_c_m
run "$M" new
G3=$(token "$M" ps_stack)
spaces=$(h workspace list | jq '.result.workspaces | length')
h workspace close "$ws" >/dev/null
sleep 2
check "closing the workspace leaves no terminal of the slot behind" eq "$(stack_size "$G3")" 0
check "and opens no workspace" eq "$(h workspace list | jq '.result.workspaces | length')" $((spaces - 1))
check "no hook failed or complained while tabs and workspaces closed" eq "$(h plugin log list --plugin dotfiles.pane-stack |
  jq --argjson t "$since" '[.result.logs[] | select(.started_unix_ms >= $t and (.exit_code != 0 or ((.stderr // "") != "")))] | length')" 0

echo "# restore after a server restart"
l_c_m
slot=$(rect_of "$M")
run "$M" new
two=$(focused)
G2=$(token "$two" ps_stack)
expected=$(stack_panes "$G2")
stop_server
start_server
check "the startup hook restores stacks after a restart" wait_for stack_is "$G2" "$expected"
check "it restores the titles" wait_for titled "$two"
run "$two" next
check "switching works after restore" eq "$(focused) $(rect_of "$M")" "$M $slot"

echo "# as a plugin action"
before=$(stack_size "$G2")
h plugin action invoke new --plugin dotfiles.pane-stack >/dev/null
check "the new action adds a terminal" wait_for grew "$G2" "$before"
check "it fills the slot" eq "$(rect_of "$(focused)")" "$slot"

echo "# goto and drop"
l_c_m
slot=$(rect_of "$M")
run "$M" new
n1=$(focused)
run "$n1" new
n2=$(focused)
G=$(token "$M" ps_stack)
run "$n2" goto "$M"
check "goto brings that terminal into the slot" eq "$rc $(focused) $(rect_of "$M")" "0 $M $slot"
check "goto parks the one shown before" eq "$(tab_of "$n2")" "$(park_tab)"
run "$M" goto "$L"
check "goto refuses a pane outside the slot" eq "$rc" 1
run "$M" drop "$n1"
check "drop closes a parked terminal" wait_for gone "$n1"
check "the shown terminal stays in the slot" eq "$(focused) $(rect_of "$M")" "$M $slot"
check "the titles count two terminals after drop" wait_for title_is "$M" "⧉ [1:zsh] 2:zsh"
run "$M" drop "$M"
check "drop of the shown terminal brings the next one in" eq "$rc $(focused) $(rect_of "$n2")" "0 $n2 $slot"
check "and the stack dissolves" wait_for unstacked "$n2"

echo "# the picker"
# picker <origin> <pane>: run the popup's body in a plain pane, where keys can reach it.
picker() {
  h pane send-text "$2" "clear; HERDR_PLUGIN_STATE_DIR=$state PANE_STACK_NOTIFY=0 PS_ORIGIN=$1 $root/pane-stack picker; echo PICKER-\$((6 * 7))" >/dev/null
  h pane send-keys "$2" enter >/dev/null
}
screen_has() { h pane read "$1" --source visible 2>/dev/null | grep -q -- "$2"; }
wait_briefly() {
  local i
  for ((i = 0; i < 8; i++)); do
    if "$@"; then return 0; fi
    sleep 0.25
  done
  return 1
}
l_c_m
slot=$(rect_of "$M")
run "$M" new
n1=$(focused)
run "$n1" new
n2=$(focused)
G=$(token "$M" ps_stack)
pws=$(h workspace create --label picker --cwd /tmp --no-focus | jq -r '.result.workspace.workspace_id')
P=$(h pane list --workspace "$pws" | jq -r '.result.panes[0].pane_id')
# A shell still starting may drop what is typed, so type until the output shows.
for _ in 1 2 3 4 5; do
  h pane send-text "$M" "echo PREVIEW-\$((2 * 3))" >/dev/null
  h pane send-keys "$M" enter >/dev/null
  if wait_briefly screen_has "$M" PREVIEW-6; then break; fi
done
picker "$n2" "$P"
check "the picker lists the stack's three terminals" wait_for screen_has "$P" "터미널 3개"
check "it previews the terminal under the cursor, the one after the shown" wait_for screen_has "$P" PREVIEW-6
h pane send-keys "$P" 1 >/dev/null
check "a digit shows that terminal" wait_for in_slot "$M" "$slot" "$main_tab"
check "and closes the picker" wait_for screen_has "$P" PICKER-42
picker "$M" "$P"
wait_for screen_has "$P" "터미널 3개" || true
h pane send-keys "$P" enter >/dev/null
check "enter shows the terminal after the shown one" wait_for in_slot "$n1" "$slot" "$main_tab"
picker "$n1" "$P"
wait_for screen_has "$P" "터미널 3개" || true
h pane send-keys "$P" ctrl+x >/dev/null
check "^X closes the terminal under the cursor" wait_for gone "$n2"
check "and keeps the list open with what is left" wait_for screen_has "$P" "닫음"
check "the slot keeps its terminal" eq "$(rect_of "$n1")" "$slot"
h pane send-keys "$P" ctrl+o >/dev/null
check "^O adds a terminal and closes the picker" wait_for screen_has "$P" PICKER-42
check "the stack has three terminals again" eq "$(stack_size "$G")" 3
check "the new terminal fills the slot" eq "$(rect_of "$(focused)")" "$slot"
picker "$L" "$P"
check "a pane without a stack shows only itself" wait_for screen_has "$P" "스택 없음"
h pane send-keys "$P" esc >/dev/null
check "esc closes the picker" wait_for screen_has "$P" PICKER-42
check "the pick action opens the popup" eq "$(HERDR_PANE_ID=$n1 h plugin action invoke pick --plugin dotfiles.pane-stack >/dev/null && sleep 1 &&
  h plugin log list --plugin dotfiles.pane-stack | jq -r '[.result.logs[] | select(.action_id == "pick")] | last | .exit_code')" 0

echo "# terminal sizes while a client draws the panes"
# Without a client herdr sizes no terminal, so a herdr client runs in a private tmux.
# size_of <pane>: the pane's terminal size as its shell sees it.
size_of() {
  local f=$tmp/size.${1//:/_} i
  rm -f "$f"
  for i in 1 2 3 4 5; do
    h pane send-text "$1" "stty size > $f" >/dev/null
    h pane send-keys "$1" enter >/dev/null
    if wait_briefly test -s "$f"; then break; fi
  done
  cat "$f" 2>/dev/null
}
if command -v tmux >/dev/null; then
  l_c_m
  tmux_server=$tmp/tmux.sock
  env -u TMUX tmux -S "$tmux_server" -f /dev/null new-session -d -x 200 -y 50 \
    "env HERDR_SOCKET_PATH=$HERDR_SOCKET_PATH HERDR_CONFIG_PATH=$HERDR_CONFIG_PATH $herdr_bin"
  sleep 3
  before=$(size_of "$M")
  run "$M" new
  n1=$(focused)
  check "a new terminal gets the slot's size" eq "$(size_of "$n1")" "$before"
  run "$n1" next
  check "a terminal brought back gets the slot's size" eq "$(size_of "$M")" "$before"
  run "$M" close
  check "the terminal that replaces a closed one gets the slot's size" eq "$(size_of "$n1")" "$before"
  # A full-screen program parked in a tab wider than the list's preview.
  cat >"$tmp/center.sh" <<'EOS'
draw() {
  local r c t i
  read -r r c < <(stty size)
  clear
  for ((i = 0; i < r / 2 - 2; i++)); do echo; done
  for t in "== DASHBOARD ==" "Find File      f" "Quit           q"; do printf '%*s%s\n' $(((c - ${#t}) / 2)) '' "$t"; done
  # nvim marks the rows past the dashboard's buffer at the left edge.
  for ((i = r / 2 + 2; i < r - 1; i++)); do echo "~"; done
}
trap draw WINCH
draw
while :; do sleep 0.05; done
EOS
  l_c_m
  h pane send-text "$M" "bash $tmp/center.sh" >/dev/null
  h pane send-keys "$M" enter >/dev/null
  wait_for screen_has "$M" DASHBOARD || true
  run "$M" new
  n1=$(focused)
  # The list runs in a pane about the size of the popup over this client.
  pws=$(h workspace create --label picker --cwd /tmp --no-focus | jq -r '.result.workspace.workspace_id')
  P=$(h pane list --workspace "$pws" | jq -r '.result.panes[0].pane_id')
  split "$P" right 0.72 >/dev/null
  split "$P" down 0.62 >/dev/null
  picker "$n1" "$P"
  check "the preview fits a wide full-screen program into view" wait_for screen_has "$P" "== DASHBOARD =="
  h pane send-keys "$P" esc >/dev/null
  env -u TMUX tmux -S "$tmux_server" kill-server 2>/dev/null || true
  tmux_server=""
else
  echo "     skipped: no tmux"
fi

echo
if ((failures)); then
  echo "$failures failed" >&2
  exit 1
fi
echo "all passed"
