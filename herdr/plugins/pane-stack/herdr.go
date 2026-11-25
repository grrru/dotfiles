package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"
)

const (
	source    = "dotfiles.pane-stack"
	parkLabel = "⧉ pane-stack"
	holdLabel = "⧉ pane-stack (정리 중)"
	// Herdr caps a title at 80 characters; a longer stack list falls back to "n/m name".
	titleMax = 80
	nameMax  = 12
)

var (
	herdrBin  string
	notifyOn  bool
	stateDir  string
	lockDir   string
	dirtyFile string
	stackFile string
	selfExe   string
)

func setup() {
	herdrBin = envOr("HERDR_BIN_PATH", "herdr")
	notifyOn = os.Getenv("PANE_STACK_NOTIFY") != "0"
	stateDir = os.Getenv("HERDR_PLUGIN_STATE_DIR")
	if stateDir == "" {
		base := os.Getenv("XDG_STATE_HOME")
		if base == "" {
			home, _ := os.UserHomeDir()
			base = filepath.Join(home, ".local", "state")
		}
		stateDir = filepath.Join(base, "herdr", "plugins", source)
	}
	lockDir = filepath.Join(stateDir, "lock")
	dirtyFile = filepath.Join(stateDir, "dirty")
	stackFile = filepath.Join(stateDir, "stacks.json")
	selfExe, _ = os.Executable()
	if real, err := filepath.EvalSymlinks(selfExe); err == nil {
		selfExe = real
	}
	setupColors()
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// herdr runs the CLI and returns its stdout. On failure the error carries herdr's
// message: the JSON error it prints, or its raw output.
func herdr(args ...string) (string, error) {
	cmd := exec.Command(herdrBin, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	if err := cmd.Run(); err != nil {
		text := strings.TrimSpace(stdout.String() + "\n" + stderr.String())
		var e struct {
			Error struct {
				Message string `json:"message"`
			} `json:"error"`
		}
		for _, part := range []string{stdout.String(), stderr.String()} {
			if json.Unmarshal([]byte(part), &e) == nil && e.Error.Message != "" {
				return "", errors.New(e.Error.Message)
			}
		}
		if text == "" {
			text = fmt.Sprintf("herdr %s failed", args[0])
		}
		return "", errors.New(text)
	}
	return stdout.String(), nil
}

func herdrJSON(v any, args ...string) error {
	out, err := herdr(args...)
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(out), v)
}

type Rect struct {
	X      int `json:"x"`
	Y      int `json:"y"`
	Width  int `json:"width"`
	Height int `json:"height"`
}

type Pane struct {
	PaneID        string            `json:"pane_id"`
	WorkspaceID   string            `json:"workspace_id"`
	TabID         string            `json:"tab_id"`
	TerminalID    string            `json:"terminal_id"`
	Cwd           string            `json:"cwd"`
	ForegroundCwd string            `json:"foreground_cwd"`
	Agent         string            `json:"agent"`
	Title         string            `json:"title"`
	Tokens        map[string]string `json:"tokens"`
}

func (p Pane) stack() string { return p.Tokens["ps_stack"] }

// order is the pane's place in its stack; a token that is not a number counts as 0.
func (p Pane) order() int {
	n, _ := strconv.Atoi(p.Tokens["ps_order"])
	return n
}

func (p Pane) dir() string {
	if p.ForegroundCwd != "" {
		return p.ForegroundCwd
	}
	return p.Cwd
}

type Tab struct {
	TabID       string `json:"tab_id"`
	WorkspaceID string `json:"workspace_id"`
	Label       string `json:"label"`
}

type LayoutPane struct {
	PaneID string `json:"pane_id"`
	Rect   Rect   `json:"rect"`
}

type Split struct {
	ID        string  `json:"id"`
	Rect      Rect    `json:"rect"`
	Direction string  `json:"direction"`
	Ratio     float64 `json:"ratio"`
}

type Layout struct {
	TabID       string       `json:"tab_id"`
	WorkspaceID string       `json:"workspace_id"`
	Zoomed      bool         `json:"zoomed"`
	Panes       []LayoutPane `json:"panes"`
	Splits      []Split      `json:"splits"`
}

func paneGet(id string) (Pane, error) {
	var r struct {
		Result struct {
			Pane Pane `json:"pane"`
		} `json:"result"`
	}
	err := herdrJSON(&r, "pane", "get", id)
	return r.Result.Pane, err
}

// listPanes lists the panes of one workspace, or of all of them for "".
func listPanes(ws string) ([]Pane, error) {
	var r struct {
		Result struct {
			Panes []Pane `json:"panes"`
		} `json:"result"`
	}
	args := []string{"pane", "list"}
	if ws != "" {
		args = append(args, "--workspace", ws)
	}
	err := herdrJSON(&r, args...)
	return r.Result.Panes, err
}

func listTabs(ws string) ([]Tab, error) {
	var r struct {
		Result struct {
			Tabs []Tab `json:"tabs"`
		} `json:"result"`
	}
	args := []string{"tab", "list"}
	if ws != "" {
		args = append(args, "--workspace", ws)
	}
	err := herdrJSON(&r, args...)
	return r.Result.Tabs, err
}

// paneList and tabList read an unreachable herdr as an empty one, for lookups that then
// find nothing to do.
func paneList(ws string) []Pane {
	ps, _ := listPanes(ws)
	return ps
}

func tabList(ws string) []Tab {
	ts, _ := listTabs(ws)
	return ts
}

func layoutOf(pane string) (Layout, error) {
	var r struct {
		Result struct {
			Layout Layout `json:"layout"`
		} `json:"result"`
	}
	err := herdrJSON(&r, "pane", "layout", "--pane", pane)
	return r.Result.Layout, err
}

func parkTab(ws string) string {
	for _, t := range tabList(ws) {
		if t.Label == parkLabel {
			return t.TabID
		}
	}
	return ""
}

// stackPanes is the stack's panes in a workspace, in stack order.
func stackPanes(ws, stack string) []Pane {
	var out []Pane
	for _, p := range paneList(ws) {
		if p.stack() == stack {
			out = append(out, p)
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].order() < out[j].order() })
	return out
}

func firstPaneIn(ws, tab string) string {
	for _, p := range paneList(ws) {
		if p.TabID == tab {
			return p.PaneID
		}
	}
	return ""
}

// tryMove runs `pane move` and returns the tab the pane landed in. A move herdr declines
// (changed: false) is an error carrying its reason.
func tryMove(args ...string) (string, error) {
	out, err := herdr(append([]string{"pane", "move"}, args...)...)
	if err != nil {
		return "", err
	}
	var r struct {
		Result struct {
			MoveResult struct {
				Changed bool   `json:"changed"`
				Reason  string `json:"reason"`
				Pane    Pane   `json:"pane"`
			} `json:"move_result"`
		} `json:"result"`
	}
	if json.Unmarshal([]byte(out), &r) != nil {
		return "", errors.New(strings.TrimSpace(out))
	}
	m := r.Result.MoveResult
	if !m.Changed {
		if m.Reason == "" {
			m.Reason = "herdr did not move the pane"
		}
		return "", errors.New(m.Reason)
	}
	return m.Pane.TabID, nil
}

func trySwap(a, b string) error {
	out, err := herdr("pane", "swap", "--source-pane", a, "--target-pane", b)
	if err != nil {
		return err
	}
	var r struct {
		Result struct {
			Swap struct {
				Changed bool   `json:"changed"`
				Reason  string `json:"reason"`
			} `json:"swap"`
		} `json:"result"`
	}
	if json.Unmarshal([]byte(out), &r) != nil {
		return errors.New(strings.TrimSpace(out))
	}
	if !r.Result.Swap.Changed {
		if r.Result.Swap.Reason == "" {
			return errors.New("herdr did not swap the panes")
		}
		return errors.New(r.Result.Swap.Reason)
	}
	return nil
}

func ratioArg(r float64) string { return strconv.FormatFloat(r, 'f', -1, 64) }

// relayout has herdr give every terminal its pane's size. After a `pane move` herdr
// leaves the terminals it touched at their old size until its next layout pass (a focus
// change, a resize), so their programs keep drawing for the wrong size; a resize by
// nothing is such a pass and changes no split.
func relayout(pane string) {
	herdr("pane", "resize", "--pane", pane, "--direction", "up", "--amount", "0")
}

func tag(pane, stack string, order int) error {
	_, err := herdr("pane", "report-metadata", pane, "--source", source,
		"--token", "ps_stack="+stack, "--token", "ps_order="+strconv.Itoa(order))
	return err
}

func untag(pane string) {
	herdr("pane", "report-metadata", pane, "--source", source,
		"--clear-token", "ps_stack", "--clear-token", "ps_order", "--clear-title")
}

func setTitle(pane, title string) {
	herdr("pane", "report-metadata", pane, "--source", source, "--title", title)
}

// nameOf is what a terminal of a stack is called: the agent herdr detects, else the
// foreground process.
func nameOf(p Pane) string {
	name := p.Agent
	if name == "" {
		var r struct {
			Result struct {
				ProcessInfo struct {
					ForegroundProcesses []struct {
						Name string `json:"name"`
					} `json:"foreground_processes"`
				} `json:"process_info"`
			} `json:"result"`
		}
		if herdrJSON(&r, "pane", "process-info", "--pane", p.PaneID) == nil &&
			len(r.Result.ProcessInfo.ForegroundProcesses) > 0 {
			name = r.Result.ProcessInfo.ForegroundProcesses[0].Name
		}
	}
	if name == "" {
		name = "sh"
	}
	return truncate(name, nameMax)
}

func truncate(s string, n int) string {
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

func notify(title, body string) {
	if body != "" {
		fmt.Fprintf(os.Stderr, "pane-stack: %s: %s\n", title, body)
	} else {
		fmt.Fprintf(os.Stderr, "pane-stack: %s\n", title)
	}
	if !notifyOn {
		return
	}
	args := []string{"notification", "show", title}
	if body != "" {
		args = append(args, "--body", body)
	}
	herdr(append(args, "--sound", "none")...)
}

// fail reports why an action stops and ends the run.
func fail(title, body string) {
	notify(title, body)
	unlock()
	os.Exit(1)
}

func currentPane() string {
	p := os.Getenv("HERDR_ACTIVE_PANE_ID")
	if p == "" {
		p = os.Getenv("HERDR_PANE_ID")
	}
	if p == "" {
		var r struct {
			Result struct {
				Pane Pane `json:"pane"`
			} `json:"result"`
		}
		if herdrJSON(&r, "pane", "current") == nil {
			p = r.Result.Pane.PaneID
		}
	}
	if p == "" {
		fail("지금 pane 을 찾지 못했습니다", "herdr 안에서 실행하세요")
	}
	return p
}
