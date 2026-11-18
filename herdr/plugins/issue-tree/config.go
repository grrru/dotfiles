package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// 실행 환경과 설정. main 에서 loadConfig 로 한 번 채운다.
var (
	herdrBin     string
	pluginID     string
	selfCmd      string // fzf 콜백에서 이 바이너리를 부르는 셸 명령
	rightCmd     string
	rightCwd     string
	ratio        string
	worktreeDir  string
	workspaceDir string
	stateDir     string
	homeDir      string

	mutedHex, lineHex string

	RESET, BOLD, MUTED, RED, GREEN, YELLOW, BLUE string
	OK, FAIL, SKIP                               string
)

const (
	tagSource = "dotfiles.issue-tree"
	tagToken  = "issue_tree"
)

func envOr(name, def string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return def
}

// loadConfig 는 환경 변수를 읽고 "$HERDR_PLUGIN_CONFIG_DIR/config.sh" 의 KEY=VALUE 줄로 덮어쓴다.
// ISSUE_TREE_RIGHT_CMD 는 빈 값(셸만 연다)과 지정하지 않음(기본 "claude agents")을 구분한다.
func loadConfig() {
	homeDir, _ = os.UserHomeDir()
	herdrBin = envOr("HERDR_BIN_PATH", "herdr")
	pluginID = envOr("HERDR_PLUGIN_ID", "dotfiles.issue-tree")
	exe, err := os.Executable()
	if err == nil {
		if real, err := filepath.EvalSymlinks(exe); err == nil {
			exe = real
		}
	}
	selfCmd = shellQuote(exe)

	if v, ok := os.LookupEnv("ISSUE_TREE_RIGHT_CMD"); ok {
		rightCmd = v
	} else {
		rightCmd = "claude agents"
	}
	rightCwd = envOr("ISSUE_TREE_RIGHT_CWD", "main")
	ratio = envOr("ISSUE_TREE_RATIO", "0.65")
	worktreeDir = os.Getenv("WORKTREE")
	workspaceDir = os.Getenv("WORKSPACE")
	if dir := os.Getenv("HERDR_PLUGIN_CONFIG_DIR"); dir != "" {
		applyConfigFile(filepath.Join(dir, "config.sh"))
	}

	// popup 은 모달이라 git 이 인증을 물으며 멈추면 herdr 화면이 막힌다. 묻지 않고 실패하게 한다.
	os.Setenv("GIT_TERMINAL_PROMPT", "0")
	if os.Getenv("GIT_SSH_COMMAND") == "" {
		os.Setenv("GIT_SSH_COMMAND", "ssh -o BatchMode=yes")
	}

	// 에이전트가 플러그인 밖에서 부를 때도 herdr 가 플러그인에 주는 state 폴더를 쓴다.
	stateDir = os.Getenv("HERDR_PLUGIN_STATE_DIR")
	if stateDir == "" {
		base := os.Getenv("XDG_STATE_HOME")
		if base == "" {
			base = filepath.Join(homeDir, ".local", "state")
		}
		stateDir = filepath.Join(base, "herdr", "plugins", pluginID)
	}

	loadColors()
}

var configLine = regexp.MustCompile(`^\s*(?:export\s+)?([A-Z_][A-Z0-9_]*)=(.*)$`)

// applyConfigFile 은 config.sh 의 KEY=VALUE 줄만 읽는다. 따옴표를 벗기고, 작은따옴표가 아니면 $HOME 같은
// 변수와 맨 앞 ~ 를 펼친다. 셸 문법은 실행하지 않는다.
func applyConfigFile(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(strings.TrimSpace(line), "#") {
			continue
		}
		m := configLine.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		key, raw := m[1], strings.TrimSpace(m[2])
		val := raw
		switch {
		case len(raw) >= 2 && raw[0] == '\'' && raw[len(raw)-1] == '\'':
			val = raw[1 : len(raw)-1]
		case len(raw) >= 2 && raw[0] == '"' && raw[len(raw)-1] == '"':
			val = expandValue(raw[1 : len(raw)-1])
		default:
			if i := strings.Index(raw, " #"); i >= 0 {
				raw = strings.TrimSpace(raw[:i])
			}
			val = expandValue(raw)
		}
		switch key {
		case "ISSUE_TREE_RIGHT_CMD":
			rightCmd = val
		case "ISSUE_TREE_RIGHT_CWD":
			rightCwd = val
		case "ISSUE_TREE_RATIO":
			ratio = val
		case "WORKTREE":
			worktreeDir = val
		case "WORKSPACE":
			workspaceDir = val
		}
	}
}

func expandValue(v string) string {
	if v == "~" || strings.HasPrefix(v, "~/") {
		v = homeDir + v[1:]
	}
	return os.ExpandEnv(v)
}

var themeLine = regexp.MustCompile(`^MODE="*([a-z]*)"*$`)

// 강조색은 ANSI 16색으로 터미널 테마를 따른다. 흐린 글씨(dim)는 라이트 테마에서 배경과 거의 같아져서
// 쓰지 않고, 보조 글씨와 테두리는 toggle-theme 가 ~/.theme_mode 에 쓰는 MODE 에 맞춘 색을 쓴다
// (라이트 Catppuccin Latte, 다크 Catppuccin Frappe 의 subtext0·surface2).
func loadColors() {
	mode := ""
	if data, err := os.ReadFile(filepath.Join(homeDir, ".theme_mode")); err == nil {
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
	// fzf 미리보기는 stdout 이 파이프라서 ISSUE_TREE_COLOR=1 로 색을 켠다.
	if isTTY(os.Stdout) || os.Getenv("ISSUE_TREE_COLOR") == "1" {
		RESET, BOLD = "\x1b[0m", "\x1b[1m"
		var r, g, b int
		fmt.Sscanf(mutedHex, "%02x%02x%02x", &r, &g, &b)
		MUTED = fmt.Sprintf("\x1b[38;2;%d;%d;%dm", r, g, b)
		RED, GREEN, YELLOW, BLUE = "\x1b[31m", "\x1b[32m", "\x1b[33m", "\x1b[34m"
	} else {
		RESET, BOLD, MUTED, RED, GREEN, YELLOW, BLUE = "", "", "", "", "", "", ""
	}
	OK = GREEN + "✓" + RESET
	FAIL = RED + "✗" + RESET
	SKIP = MUTED + "·" + RESET
}

func isTTY(f *os.File) bool {
	fi, err := f.Stat()
	return err == nil && fi.Mode()&os.ModeCharDevice != 0
}

// requireEnv 는 WORKTREE 와 WORKSPACE 가 폴더인지 본다.
func requireEnv() bool {
	for _, kv := range [][2]string{{"WORKTREE", worktreeDir}, {"WORKSPACE", workspaceDir}} {
		if fi, err := os.Stat(kv[1]); kv[1] != "" && err == nil && fi.IsDir() {
			continue
		}
		cfgDir := os.Getenv("HERDR_PLUGIN_CONFIG_DIR")
		if cfgDir == "" {
			cfgDir = "<plugin config-dir>"
		}
		fmt.Printf("%s%s 설정 오류%s · '%s' (폴더 아님)\n", RED, kv[0], RESET, kv[1])
		fmt.Printf("설정 위치 · herdr 서버 환경 또는 %s/config.sh\n", cfgDir)
		return false
	}
	return true
}
