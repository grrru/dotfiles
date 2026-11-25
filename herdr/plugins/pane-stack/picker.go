package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

// cmdPick lists the current pane's stack in a popup. The popup has no
// pane of its own in herdr's API, so the pane it acts on travels as PS_ORIGIN.
func cmdPick() int {
	origin := os.Getenv("HERDR_ACTIVE_PANE_ID")
	if origin == "" {
		origin = os.Getenv("HERDR_PANE_ID")
	}
	args := []string{"plugin", "pane", "open", "--plugin", envOr("HERDR_PLUGIN_ID", source), "--entrypoint", "picker", "--focus"}
	if origin != "" {
		args = append(args, "--env", "PS_ORIGIN="+origin)
	}
	// The popup must use this run's lock and state file.
	args = append(args, "--env", "HERDR_PLUGIN_STATE_DIR="+stateDir)
	if _, err := herdr(args...); err != nil {
		notify("스택 목록을 열지 못했습니다", err.Error())
		return 1
	}
	return 0
}

// view is a slot as the picker shows it: the stack's terminals, or the origin pane alone
// when it has no stack.
type view struct {
	origin  string
	stack   string
	shown   string
	members []Pane
	parked  map[string]bool
}

func resolve(origin string) (view, error) {
	p, err := paneGet(origin)
	if err != nil {
		return view{}, err
	}
	v := view{origin: origin, stack: p.stack(), parked: map[string]bool{}}
	if v.stack == "" {
		v.members, v.shown = []Pane{p}, origin
		return v, nil
	}
	park := parkTab(p.WorkspaceID)
	v.members = stackPanes(p.WorkspaceID, v.stack)
	var shown []string
	for _, m := range v.members {
		if park != "" && m.TabID == park {
			v.parked[m.PaneID] = true
		} else {
			shown = append(shown, m.PaneID)
		}
	}
	if len(shown) == 1 {
		v.shown = shown[0]
	}
	return v, nil
}

func (v view) items() string {
	var b strings.Builder
	for i, m := range v.members {
		mark := "  "
		if m.PaneID == v.shown {
			mark = GREEN + "●" + RESET + " "
		}
		fmt.Fprintf(&b, "%s\t%s%s%d%s  %s%-12s%s  %s%s%s\n", m.PaneID, mark, BLUE, i+1, RESET,
			BOLD, nameOf(m), RESET, MUTED, tilde(m.dir()), RESET)
	}
	return b.String()
}

// act runs an action of this binary on the origin pane and returns its first complaint.
func act(origin string, args ...string) (bool, string) {
	cmd := exec.Command(selfExe, args...)
	env := []string{"HERDR_PANE_ID=" + origin, "PANE_STACK_NOTIFY=0"}
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "HERDR_ACTIVE_PANE_ID=") && !strings.HasPrefix(kv, "HERDR_PANE_ID=") &&
			!strings.HasPrefix(kv, "PANE_STACK_NOTIFY=") {
			env = append(env, kv)
		}
	}
	cmd.Env = env
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if cmd.Run() == nil {
		return true, ""
	}
	msg := strings.TrimSpace(stderr.String())
	if i := strings.IndexByte(msg, '\n'); i >= 0 {
		msg = msg[:i]
	}
	return false, strings.TrimPrefix(msg, "pane-stack: ")
}

// cmdPicker is the popup: the stack's terminals with the screen of the one under the
// cursor. Enter or a digit brings a terminal in, ^O adds a new one, ^X closes the one
// under the cursor and keeps the list open.
func cmdPicker() int {
	origin := os.Getenv("PS_ORIGIN")
	if origin == "" {
		origin = currentPane()
	}
	flash := ""
	for {
		v, err := resolve(origin)
		if err != nil {
			pause(RED + "✗" + RESET + " pane " + origin + " 을 찾지 못했습니다")
			return 0
		}
		n := len(v.members)
		label := fmt.Sprintf(" 스택 · 터미널 %d개 ", n)
		if v.stack == "" {
			label = " 스택 없음 "
		}
		if flash != "" {
			label = " " + flash + " "
		}
		keys := []string{"ctrl-o", "ctrl-x"}
		for i := 1; i <= min(n, 9); i++ {
			keys = append(keys, strconv.Itoa(i))
		}
		// The cursor starts on the terminal after the shown one, so Enter alone works as next.
		start := 1
		for i, m := range v.members {
			if m.PaneID == v.shown && n > 1 {
				start = (i+1)%n + 1
			}
		}
		help := " ↵ 전환 · 1-9 바로 · ^O 새 터미널 · ^X 닫기 "
		args := []string{
			"--delimiter=\t", "--with-nth=2..", "--no-sort", "--expect=" + strings.Join(keys, ","),
			"--input-label=" + help, "--input-label-pos=-2",
			"--list-label=" + label, "--list-label-pos=2",
			"--bind=load:pos(" + strconv.Itoa(start) + ")",
			"--preview=" + shellQuote(selfExe) + " preview {1}",
			"--preview-window=right,62%,<70(down,60%)", "--preview-label= 화면 ", "--preview-label-pos=2",
		}
		out, rc := fz(v.items(), args...)
		if rc == 130 {
			return 0
		}
		if rc > 1 {
			pause(fmt.Sprintf("%s✗%s fzf 오류 (exit %d)", RED, RESET, rc))
			return 0
		}
		lines := strings.Split(out, "\n")
		key, pick := lines[0], ""
		if len(lines) > 1 {
			pick = strings.SplitN(lines[1], "\t", 2)[0]
		}
		if d, err := strconv.Atoi(key); err == nil && d >= 1 && d <= n {
			key, pick = "", v.members[d-1].PaneID
		}
		flash = ""
		switch key {
		case "ctrl-o":
			if ok, why := act(origin, "new"); !ok {
				flash = "✗ " + why
				continue
			}
			return 0
		case "ctrl-x":
			if pick == "" {
				continue
			}
			before := v.members
			name := nameOf(paneByID(before, pick))
			ok, why := act(origin, "drop", pick)
			if !ok {
				flash = "✗ " + why
				continue
			}
			flash = "✓ " + name + " 닫음"
			origin = shownAfter(before, pick, origin)
		default:
			if pick == "" || pick == v.shown {
				return 0
			}
			if ok, why := act(origin, "goto", pick); !ok {
				flash = "✗ " + why
				continue
			}
			return 0
		}
	}
}

func paneByID(ps []Pane, id string) Pane {
	for _, p := range ps {
		if p.PaneID == id {
			return p
		}
	}
	return Pane{PaneID: id}
}

// shownAfter is the pane to keep acting on after one terminal of the slot closed: the
// origin while it lives, else the terminal that came into the slot.
func shownAfter(before []Pane, gone, origin string) string {
	if origin != gone {
		if _, err := paneGet(origin); err == nil {
			return origin
		}
	}
	var alive []Pane
	for _, m := range before {
		if m.PaneID == gone {
			continue
		}
		if p, err := paneGet(m.PaneID); err == nil {
			alive = append(alive, p)
		}
	}
	for _, p := range alive {
		if park := parkTab(p.WorkspaceID); park == "" || p.TabID != park {
			return p.PaneID
		}
	}
	if len(alive) > 0 {
		return alive[0].PaneID
	}
	return origin
}

// cmdPreview prints a terminal's screen for the picker, fitted to the preview.
func cmdPreview(pane string) int {
	rows, cols := 40, 80
	if n, err := strconv.Atoi(os.Getenv("FZF_PREVIEW_LINES")); err == nil && n > 0 {
		rows = n
	}
	if n, err := strconv.Atoi(os.Getenv("FZF_PREVIEW_COLUMNS")); err == nil && n > 0 {
		cols = n
	}
	out, err := herdr("pane", "read", pane, "--source", "visible", "--ansi")
	if err != nil {
		fmt.Println(MUTED + "화면을 읽지 못했습니다 · " + err.Error() + RESET)
		return 0
	}
	fmt.Println(fitScreen(out, rows, cols))
	return 0
}

var ansiSeq = regexp.MustCompile(`\x1b\[[0-9;?:<=>]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b.`)

// fitScreen fits a terminal screen into a preview of rows x cols. The screen comes from a
// terminal of another size, often wider than the preview, and a full-screen program
// centers its content there. So blank rows at either end and the blank columns every row
// starts with go, and content that was set off from the top or left edge is centered in
// the preview again. A row holding only vim's "~" end-of-buffer mark counts as blank, or
// the marks down the left edge of a dashboard would keep it off to the right. A screen
// that starts at its top left, like a shell's, keeps its last rows.
func fitScreen(screen string, rows, cols int) string {
	lines := strings.Split(strings.ReplaceAll(screen, "\r", ""), "\n")
	for i, l := range lines {
		if strings.TrimSpace(ansiSeq.ReplaceAllString(l, "")) == "~" {
			lines[i] = ""
		}
	}
	blank := func(l string) bool { return strings.TrimSpace(ansiSeq.ReplaceAllString(l, "")) == "" }
	top := 0
	for len(lines) > 0 && blank(lines[0]) {
		lines = lines[1:]
		top++
	}
	for len(lines) > 0 && blank(lines[len(lines)-1]) {
		lines = lines[:len(lines)-1]
	}
	if len(lines) > rows {
		lines = lines[len(lines)-rows:]
	}
	indent := -1
	for _, l := range lines {
		if !blank(l) {
			if n := leadingSpaces(l); indent < 0 || n < indent {
				indent = n
			}
		}
	}
	width := 0
	for i := range lines {
		lines[i] = strings.TrimRight(dropSpaces(lines[i], indent), " ")
		width = max(width, shownWidth(strings.TrimRight(ansiSeq.ReplaceAllString(lines[i], ""), " ")))
	}
	if indent > 0 && width < cols {
		pad := strings.Repeat(" ", (cols-width)/2)
		for i := range lines {
			if !blank(lines[i]) {
				lines[i] = pad + lines[i]
			}
		}
	}
	if top > 0 && len(lines) < rows {
		lines = append(make([]string, (rows-len(lines))/2), lines...)
	}
	return strings.Join(lines, "\n")
}

// shownWidth is how many cells a line takes, counting East Asian wide characters as two.
func shownWidth(l string) int {
	n := 0
	for _, r := range ansiSeq.ReplaceAllString(l, "") {
		switch {
		case r >= 0x1100 && r <= 0x115F, r >= 0x2E80 && r <= 0xA4CF, r >= 0xAC00 && r <= 0xD7A3,
			r >= 0xF900 && r <= 0xFAFF, r >= 0xFE30 && r <= 0xFE4F, r >= 0xFF00 && r <= 0xFF60,
			r >= 0xFFE0 && r <= 0xFFE6, r >= 0x1F300 && r <= 0x1FAFF, r >= 0x20000 && r <= 0x3FFFD:
			n += 2
		default:
			n++
		}
	}
	return n
}

// leadingSpaces counts the spaces a line shows before its first other character,
// passing over escape sequences.
func leadingSpaces(l string) int {
	n := 0
	for i := 0; i < len(l); {
		if loc := ansiSeq.FindStringIndex(l[i:]); loc != nil && loc[0] == 0 {
			i += loc[1]
			continue
		}
		if l[i] != ' ' {
			break
		}
		n++
		i++
	}
	return n
}

// dropSpaces removes the first k shown spaces of a line and keeps its escape sequences.
func dropSpaces(l string, k int) string {
	var b strings.Builder
	i := 0
	for i < len(l) && k > 0 {
		if loc := ansiSeq.FindStringIndex(l[i:]); loc != nil && loc[0] == 0 {
			b.WriteString(l[i : i+loc[1]])
			i += loc[1]
			continue
		}
		if l[i] != ' ' {
			break
		}
		k--
		i++
	}
	b.WriteString(l[i:])
	return b.String()
}
