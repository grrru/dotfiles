package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

var (
	mutedHex, lineHex                    string
	RESET, BOLD, MUTED, GREEN, RED, BLUE string
)

var themeLine = regexp.MustCompile(`^MODE="*([a-z]*)"*$`)

// setupColors follows the light or dark mode in ~/.theme_mode, as issue-tree does.
func setupColors() {
	mode := ""
	home, _ := os.UserHomeDir()
	if data, err := os.ReadFile(filepath.Join(home, ".theme_mode")); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if m := themeLine.FindStringSubmatch(line); m != nil {
				mode = m[1]
			}
		}
	}
	if mode == "dark" {
		mutedHex, lineHex = "a5adce", "626880"
	} else {
		mutedHex, lineHex = "6c6f85", "acb0be"
	}
	var r, g, b int
	fmt.Sscanf(mutedHex, "%02x%02x%02x", &r, &g, &b)
	RESET, BOLD = "\x1b[0m", "\x1b[1m"
	MUTED = fmt.Sprintf("\x1b[38;2;%d;%d;%dm", r, g, b)
	GREEN, RED, BLUE = "\x1b[32m", "\x1b[31m", "\x1b[34m"
}

func fzBase() []string {
	return []string{
		"--ansi", "--style=full", "--layout=reverse", "--cycle", "--info=hidden",
		"--prompt=› ", "--pointer=▌", "--with-shell=bash -c",
		"--color=16,fg:-1,bg:-1,list-bg:-1,input-bg:-1,header-bg:-1,preview-bg:-1,selected-bg:-1,gutter:-1",
		"--color=fg+:-1:bold,bg+:-1,hl:blue:bold,hl+:blue:bold,query:-1:bold,disabled:-1:bold,header:-1",
		"--color=pointer:blue,marker:green,prompt:blue,spinner:blue,label:-1:bold",
		fmt.Sprintf("--color=info:#%s,border:#%s,separator:#%s,gap-line:#%s,scrollbar:#%s", mutedHex, lineHex, lineHex, lineHex, lineHex),
		fmt.Sprintf("--color=list-border:#%s,input-border:#%s,header-border:#%s,preview-border:#%s", lineHex, lineHex, lineHex, lineHex),
	}
}

// fz runs fzf and returns its output without the final newline, and its exit code:
// 0 chosen, 1 no match, 130 esc, 2 error.
func fz(input string, args ...string) (string, int) {
	cmd := exec.Command("fzf", append(fzBase(), args...)...)
	cmd.Stdin = strings.NewReader(input)
	cmd.Stderr = os.Stderr
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
	fmt.Printf("\n%s\n%s↵ 닫기%s", msg, MUTED, RESET)
	bufio.NewReader(os.Stdin).ReadString('\n')
}

func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

func tilde(path string) string {
	home, _ := os.UserHomeDir()
	if home != "" && (path == home || strings.HasPrefix(path, home+"/")) {
		return "~" + strings.TrimPrefix(path, home)
	}
	return path
}
