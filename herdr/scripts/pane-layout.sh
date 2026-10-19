#!/bin/sh
# 현재 탭의 패널을 tmux 에서 쓰던 프리셋대로 다시 배치한다.
#
#   pane-layout.sh two            패널 2개를 좌우로 놓고 포커스된 패널 68%, 나머지 32%
#   pane-layout.sh three [size]   패널 3개를 왼쪽 위·아래 + 오른쪽 하나로 놓는다 (좌우 68:32).
#                                 size 는 왼쪽 아래 패널 높이로, 퍼센트(기본 30) 또는 "Nlines"
#
# 패널 순서는 herdr 레이아웃 순서(왼쪽 위부터)를 따르고, 포커스는 원래 패널에 남긴다.
# herdr [[keys.command]] (type = "shell") 에서 실행하면 HERDR_ACTIVE_PANE_ID 로 포커스된 패널을 받는다.
# herdr 는 분할 비율을 0.1~0.9 로 제한하므로 아래 패널은 탭 높이의 10% 보다 작아지지 않는다.

set -eu

herdr=${HERDR_BIN_PATH:-herdr}
mode=${1:-two}
size=${2:-30}
active=${HERDR_ACTIVE_PANE_ID:?}

notify() {
  "$herdr" notification show "$1" >/dev/null
}

layout=$("$herdr" pane layout --pane "$active")

field() {
  printf '%s' "$layout" | jq -r "$1"
}

tab=$(field '.result.layout.tab_id')
count=$(field '.result.layout.panes | length')
height=$(field '.result.layout.area.height')
p1=$(field '.result.layout.panes[0].pane_id')
p2=$(field '.result.layout.panes[1].pane_id // ""')
p3=$(field '.result.layout.panes[2].pane_id // ""')

focus_flag() {
  if [ "$1" = "$active" ]; then
    echo --focus
  else
    echo --no-focus
  fi
}

# 같은 탭 안의 pane move 는 배치를 바꾸지 않으므로 임시 탭으로 옮겼다가 되돌린다.
# 옮긴 패널이 빠져 임시 탭이 비면 herdr 가 그 탭을 닫는다.
park() {
  "$herdr" pane move "$1" --new-tab --no-focus | jq -r '.result.move_result.pane.tab_id'
}

# put_back <pane> <right|down> <target> <ratio>: ratio 는 target 쪽이 차지하는 비율이다.
put_back() {
  "$herdr" pane move "$1" --tab "$tab" --split "$2" --target-pane "$3" --ratio "$4" "$(focus_flag "$1")" >/dev/null
}

two() {
  if [ "$count" -ne 2 ]; then
    notify "2분할 프리셋은 패널이 2개일 때만 동작합니다"
    return 0
  fi
  target=0.32
  if [ "$active" = "$p1" ]; then
    target=0.68
  fi

  if [ "$(field '.result.layout.splits[0].direction')" != right ]; then
    park "$p2" >/dev/null
    put_back "$p2" right "$p1" "$target"
    return 0
  fi

  # resize 는 분할선을 amount 만큼 left/right 로 옮긴다 (ratio 가 그만큼 줄거나 는다).
  ratio=$(field '.result.layout.splits[0].ratio')
  delta=$(awk -v t="$target" -v r="$ratio" 'BEGIN { printf "%.4f", t - r }')
  case $delta in
  -*) "$herdr" pane resize --pane "$active" --direction left --amount "${delta#-}" >/dev/null ;;
  *) "$herdr" pane resize --pane "$active" --direction right --amount "$delta" >/dev/null ;;
  esac
}

three() {
  if [ "$count" -ne 3 ]; then
    notify "3분할 프리셋은 패널이 3개일 때만 동작합니다"
    return 0
  fi

  # 패널 높이에는 위아래 테두리 2줄이 포함된다.
  case $size in
  *lines) top=$(awk -v h="$height" -v n="${size%lines}" 'BEGIN { printf "%.4f", (h - n - 2) / h }') ;;
  *) top=$(awk -v p="${size%\%}" 'BEGIN { printf "%.4f", 1 - p / 100 }') ;;
  esac

  tmp=$(park "$p2")
  "$herdr" pane move "$p3" --tab "$tmp" --split right --no-focus >/dev/null
  put_back "$p3" right "$p1" 0.68
  put_back "$p2" down "$p1" "$top"
}

case $mode in
two) two ;;
three) three ;;
*)
  notify "pane-layout.sh: 알 수 없는 모드 '$mode' (two|three)"
  exit 1
  ;;
esac
