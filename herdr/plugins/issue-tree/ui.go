package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// fzBase 는 모든 화면이 같이 쓰는 fzf 모양이다.
func fzBase() []string {
	return []string{
		"--ansi", "--style=full", "--layout=reverse", "--cycle", "--info=inline-right",
		"--prompt=› ", "--pointer=▌", "--with-shell=bash -c",
		"--color=16,fg:-1,bg:-1,list-bg:-1,input-bg:-1,header-bg:-1,preview-bg:-1,selected-bg:-1,gutter:-1",
		"--color=fg+:-1:bold,bg+:-1,hl:blue:bold,hl+:blue:bold,query:-1:bold,disabled:-1:bold,header:-1",
		"--color=pointer:blue,marker:green,prompt:blue,spinner:blue,label:-1:bold",
		fmt.Sprintf("--color=info:#%s,border:#%s,separator:#%s,gap-line:#%s,scrollbar:#%s", mutedHex, lineHex, lineHex, lineHex, lineHex),
		fmt.Sprintf("--color=list-border:#%s,input-border:#%s,header-border:#%s,preview-border:#%s", lineHex, lineHex, lineHex, lineHex),
	}
}

// fz 는 fzf 를 띄워 출력(끝 줄바꿈 제외)과 종료 코드를 돌려준다.
// 종료 코드는 0 선택, 1 일치 없음(입력만), 130 esc, 2 오류.
func fz(input string, env []string, args ...string) (string, int) {
	cmd := exec.Command("fzf", append(fzBase(), args...)...)
	cmd.Stdin = strings.NewReader(input)
	cmd.Stderr = os.Stderr
	cmd.Env = append(os.Environ(), env...)
	out, err := cmd.Output()
	code := 0
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			code = exitErr.ExitCode()
		} else {
			code = 2
		}
	}
	return strings.TrimRight(string(out), "\n"), code
}

func pause(msg string) {
	if !isTTY(os.Stdin) {
		return
	}
	if msg == "" {
		msg = "↵ 닫기"
	}
	fmt.Printf("\n%s%s%s", MUTED, msg, RESET)
	bufio.NewReader(os.Stdin).ReadString('\n')
}

func clearScreen() {
	if isTTY(os.Stdout) {
		fmt.Print("\x1b[H\x1b[2J")
	}
}

func fzfFailed(code int) {
	clearScreen()
	fmt.Printf("%s fzf 오류 (exit %d)\n", FAIL, code)
	pause("")
}

// badges 는 목록 카드의 레포 상태 "✎4 ↑2" 다. 둘 다 0 이면 "✓".
func badges(dirty, ahead int) string {
	var parts []string
	if dirty > 0 {
		parts = append(parts, fmt.Sprintf("%s✎%d%s", YELLOW, dirty, RESET))
	}
	if ahead > 0 {
		parts = append(parts, fmt.Sprintf("%s↑%d%s", GREEN, ahead, RESET))
	}
	if len(parts) == 0 {
		parts = []string{GREEN + "✓" + RESET}
	}
	return strings.Join(parts, " ")
}

// stateWords 는 상세의 레포 상태 "변경 4 · push 전 2" 다. 둘 다 0 이면 "✓ clean".
func stateWords(dirty, ahead int) string {
	out := ""
	if dirty > 0 {
		out = fmt.Sprintf("%s변경 %d%s", YELLOW, dirty, RESET)
	}
	if ahead > 0 {
		if out != "" {
			out += " · "
		}
		out += fmt.Sprintf("%spush 전 %d%s", GREEN, ahead, RESET)
	}
	if out == "" {
		return GREEN + "✓ clean" + RESET
	}
	return out
}
