#!/usr/bin/env bash
# pane-stack 플러그인을 빌드하고 herdr 에 링크한다. 다시 실행해도 되므로 코드를 받은 뒤에도 이것을 실행한다.
#
#   ./install.sh           빌드 후 링크
#   ./install.sh --build   빌드만
#
# Go 는 go.mod 의 go 버전 이상인 것을 PANE_STACK_GO, PATH 의 go, ~/sdk/go*/bin/go, /usr/local/go/bin/go
# 순서로 찾는다. 셸의 GOROOT 가 다른 버전을 가리켜도 찾은 Go 가 자기 GOROOT 를 쓰도록 GOROOT 를 지우고,
# 모자란 toolchain 을 내려받지 않도록 GOTOOLCHAIN=local 로 둔다.
set -euo pipefail

usage() { echo "usage: $0 [--build]" >&2; }
build_only=0
case "${1:-}" in
"") ;;
--build) build_only=1 ;;
*)
  usage
  exit 2
  ;;
esac

cd "$(dirname "$0")"
dir="$(pwd -P)"

unset GOROOT
export GOTOOLCHAIN=local

if [ -t 1 ]; then
  OK=$'\e[32m✓\e[0m' FAIL=$'\e[31m✗\e[0m' WARN=$'\e[33m⚠\e[0m'
else
  OK='✓' FAIL='✗' WARN='⚠'
fi

# 점으로 나눈 앞 세 자리를 숫자로 비교한다 (dotfiles install.sh 와 같음).
version_at_least() {
  awk -v current="${1#v}" -v required="${2#v}" '
    BEGIN {
      split(current, current_parts, ".")
      split(required, required_parts, ".")
      for (i = 1; i <= 3; i++) {
        current_part = current_parts[i] + 0
        required_part = required_parts[i] + 0
        if (current_part > required_part) exit 0
        if (current_part < required_part) exit 1
      }
      exit 0
    }
  '
}

show() {
  case "$1" in
  "$HOME"/*) echo "~${1#"$HOME"}" ;;
  *) echo "$1" ;;
  esac
}

need_go="$(awk '$1 == "go" { print $2; exit }' go.mod)"
go_bin="" go_ver="" tried="|" seen=""

try_go() {
  local v
  [ -z "$go_bin" ] && [ -x "$1" ] || return 0
  case "$tried" in *"|$1|"*) return 0 ;; esac
  tried="$tried$1|"
  v="$("$1" env GOVERSION 2>/dev/null)" || v=""
  seen="$seen  ${v:-버전 모름} · $(show "$1")"$'\n'
  if [ -n "$v" ] && version_at_least "${v#go}" "$need_go"; then
    go_bin="$1" go_ver="$v"
  fi
}

if [ -n "${PANE_STACK_GO:-}" ]; then
  try_go "$PANE_STACK_GO"
else
  try_go "$(command -v go 2>/dev/null || true)"
  for g in "$HOME"/sdk/go*/bin/go /usr/local/go/bin/go; do
    try_go "$g"
  done
fi

if [ -z "$go_bin" ]; then
  echo "$FAIL Go $need_go 이상 없음" >&2
  [ -n "$seen" ] && printf '찾은 Go\n%s' "$seen" >&2
  echo "다른 위치의 Go 지정 · PANE_STACK_GO=/path/to/go $0" >&2
  exit 1
fi

# 실행 중인 popup 과 hook 이 쓰던 바이너리를 건드리지 않도록 새 파일로 빌드한 뒤 바꿔 넣는다.
trap 'rm -f .pane-stack.new' EXIT
if ! "$go_bin" build -o .pane-stack.new .; then
  echo "$FAIL 빌드 실패 · $go_ver · $(show "$go_bin")" >&2
  exit 1
fi
mv -f .pane-stack.new pane-stack
echo "$OK 빌드 · $go_ver · $(show "$go_bin")"

[ "$build_only" = 1 ] && exit 0

if ! command -v herdr >/dev/null 2>&1; then
  echo "$FAIL herdr 없음 · 빌드만 함" >&2
  exit 1
fi
if ! herdr plugin link "$dir" >/dev/null; then
  echo "$FAIL 링크 실패 · $(show "$dir")" >&2
  exit 1
fi
echo "$OK 링크 · $(show "$dir")"

fzf_ver="$(fzf --version 2>/dev/null | awk 'NR == 1 { print $1 }')" || fzf_ver=""
if [ -z "$fzf_ver" ]; then
  echo "$WARN fzf 없음 · 스택 목록(C-a S)에 0.58 이상 필요"
elif ! version_at_least "$fzf_ver" 0.58; then
  echo "$WARN fzf $fzf_ver · 스택 목록(C-a S)에 0.58 이상 필요"
fi
