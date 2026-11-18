package main

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// treeItems 는 fzf --read0 항목이다. 항목마다 "dir<TAB>" 뒤에 두 줄 카드가 온다.
//
//	● #123  login       2일 전
//	  api ✎4   web ✎6
//
// 레포 마지막 커밋과 tracker 수정 시각 중 늦은 쪽(최근 작업)이 앞에 온다.
func treeItems() string {
	type card struct {
		dir, num, tag, repos string
		latest               int64
		idx                  int
	}
	var cards []card
	numw, tagw := 0, 0
	for i, dir := range treeDirs() {
		var latest int64
		if fi, err := os.Stat(filepath.Join(dir, trackerName)); err == nil {
			latest = fi.ModTime().Unix()
		}
		repos := ""
		for _, r := range repoRows(dir) {
			st, ok := repoInfo(r.Worktree)
			if !ok {
				repos += "   " + base(r.Repo) + " " + RED + "없음" + RESET
				continue
			}
			if st.Last > latest {
				latest = st.Last
			}
			repos += "   " + base(r.Repo) + " " + badges(st.Dirty, st.Ahead)
		}
		c := card{dir, treeNum(dir), treeTag(dir), strings.TrimPrefix(repos, " "), latest, i}
		cards = append(cards, c)
		numw = max(numw, len(c.num))
		tagw = max(tagw, len(c.tag), 1)
	}
	sort.SliceStable(cards, func(a, b int) bool {
		if cards[a].latest != cards[b].latest {
			return cards[a].latest > cards[b].latest
		}
		return strconv.Itoa(cards[a].idx) > strconv.Itoa(cards[b].idx)
	})
	var b strings.Builder
	for _, c := range cards {
		dot := MUTED + "○" + RESET
		if _, _, ok := workspaceFor(c.dir); ok {
			dot = GREEN + "●" + RESET
		}
		tag := c.tag
		if tag == "" {
			tag = "—"
		}
		fmt.Fprintf(&b, "%s\t%s %s%s%s  %s%s%s  %s%s%s\n%s\x00", c.dir, dot,
			BLUE, pad("#"+c.num, numw+1), RESET, BOLD, pad(tag, tagw), RESET, MUTED, ago(c.latest), RESET, c.repos)
	}
	return b.String()
}

// flashTimer 는 결과 문구가 붙은 목록 라벨을 3초 뒤 원래 라벨로 되돌린다. fzf 에는 타이머가 없어서
// --listen 포트로 라벨 변경을 보낸다. 같은 장비의 다른 사용자가 보내지 못하게 API 키를 걸고,
// --listen 은 명령 실행 동작을 받지 않는다. stop 을 부르면 보내기 전에 그만둔다.
type flashTimer struct {
	dir, key string
	done     chan struct{}
}

func startFlash(label string) (*flashTimer, []string, []string) {
	dir, err := os.MkdirTemp("", "issue-tree-flash.")
	if err != nil {
		return nil, nil, nil
	}
	t := &flashTimer{dir: dir, key: newID() + newID() + newID(), done: make(chan struct{})}
	portFile := filepath.Join(dir, "port")
	args := []string{"--listen", "--bind=start:execute-silent:echo $FZF_PORT >" + shellQuote(portFile)}
	go func() {
		begin := time.Now()
		port := ""
		for port == "" && time.Since(begin) < 5*time.Second {
			select {
			case <-t.done:
				return
			case <-time.After(50 * time.Millisecond):
			}
			if data, err := os.ReadFile(portFile); err == nil {
				port = strings.TrimSpace(string(data))
			}
		}
		if port == "" {
			return
		}
		select {
		case <-t.done:
			return
		case <-time.After(3*time.Second - time.Since(begin)):
		}
		req, err := http.NewRequest("POST", "http://localhost:"+port, strings.NewReader("change-list-label("+label+")"))
		if err != nil {
			return
		}
		req.Header.Set("x-api-key", t.key)
		client := &http.Client{Timeout: 2 * time.Second}
		if resp, err := client.Do(req); err == nil {
			resp.Body.Close()
		}
	}()
	return t, args, []string{"FZF_API_KEY=" + t.key}
}

func (t *flashTimer) stop() {
	if t == nil {
		return
	}
	close(t.done)
	os.RemoveAll(t.dir)
}

func cmdPicker() int {
	if !requireEnv() {
		pause("")
		return 0
	}
	flash := ""
	for {
		count := len(treeDirs())
		if count == 0 {
			wizardNew()
			return 0
		}
		label := fmt.Sprintf(" %d개 · 최근 작업순 ", count)
		var timer *flashTimer
		var flashArgs, flashEnv []string
		if flash != "" {
			plain := label
			label = fmt.Sprintf(" %s · %d개 ", flash, count)
			timer, flashArgs, flashEnv = startFlash(plain)
		}
		args := []string{
			"--read0", "--delimiter=\t", "--with-nth=2..", "--expect=ctrl-o,ctrl-r,ctrl-x",
			"--gap", "--no-sort",
			"--input-label= ↵ 열기 · ^O 새 tree · ^R 레포 추가 · ^X 정리 · esc 닫기 ", "--input-label-pos=-2",
			"--list-label=" + label, "--list-label-pos=2",
			"--preview=ISSUE_TREE_COLOR=1 " + selfCmd + " preview {1}",
			"--preview-window=right,55%,<60(down,50%)", "--preview-label= 상세 ", "--preview-label-pos=2",
		}
		out, rc := fz(treeItems(), flashEnv, append(args, flashArgs...)...)
		timer.stop()
		if rc == 130 {
			return 0
		}
		if rc > 1 {
			fzfFailed(rc)
			return 0
		}

		// --expect 키는 검색에 맞는 항목이 없어도(rc 1) 첫 줄에 온다
		outLines := strings.Split(out, "\n")
		key, dir := outLines[0], ""
		if len(outLines) > 1 {
			dir = strings.SplitN(outLines[1], "\t", 2)[0]
		}
		flash = ""
		switch key {
		case "ctrl-o":
			if wizardNew() {
				return 0
			}
		case "ctrl-r":
			if dir != "" && wizardAdd(dir) {
				return 0
			}
		case "ctrl-x":
			if dir != "" && cleanFlow(dir) {
				flash = OK + " " + base(dir) + " 정리 완료"
			}
		default:
			if dir == "" {
				return 0
			}
			if _, _, err := openTree(dir, ""); err != nil {
				fmt.Fprintln(os.Stderr, err)
				return 1
			}
			return 0
		}
	}
}

// otherEntries 는 이슈 폴더에서 tracker 와 tracker 의 worktree 를 뺀 항목이다. 폴더는 끝에 / 를 붙이고
// 링크는 붙이지 않는다. 숨김 항목은 뒤에 온다.
func otherEntries(dir string, tracked map[string]bool) []string {
	entries, _ := os.ReadDir(dir)
	var plain, dot []string
	for _, e := range entries {
		name := e.Name()
		if name == trackerName || tracked[name] || strings.HasPrefix(name, "..") {
			continue
		}
		if e.Type()&os.ModeSymlink == 0 && e.IsDir() {
			name += "/"
		}
		if strings.HasPrefix(name, ".") {
			dot = append(dot, name)
		} else {
			plain = append(plain, name)
		}
	}
	return append(plain, dot...)
}

// cmdPreview 는 목록의 상세다. 무엇을 여는지(번호·태그·워크스페이스·브랜치) → 레포별 상태 한 줄 →
// 마지막 커밋 → 바뀐 파일 → 이슈 폴더의 다른 항목 → 경로 순으로, 위에 둘수록 고를 때 먼저 보는 정보다.
func cmdPreview(dir string) int {
	tag := treeTag(dir)
	branch := trackerGet(dir, "BRANCH")
	tagText := tag
	if tagText == "" {
		tagText = MUTED + "태그 없음"
	}
	fmt.Printf("%s#%s%s  %s%s%s\n", BLUE+BOLD, treeNum(dir), RESET, BOLD, tagText, RESET)
	if ws, how, ok := workspaceFor(dir); ok {
		label := workspaceLabel(ws)
		if label == "" {
			label = ws
		}
		extra := ""
		if how == "cwd" {
			extra = " · 경로 기준"
		}
		fmt.Printf("%s●%s 워크스페이스 %s%s%s %s· ↵ 전환%s%s\n", GREEN, RESET, BOLD, label, RESET, MUTED, extra, RESET)
	} else {
		fmt.Printf("%s○ 워크스페이스 없음 · ↵ 새로 열기%s\n", MUTED, RESET)
	}
	fmt.Printf("%s%s%s\n", MUTED, branch, RESET)

	rows := repoRows(dir)
	w := 0
	tracked := map[string]bool{}
	for _, r := range rows {
		w = max(w, len(base(r.Repo)))
	}
	for _, r := range rows {
		tracked[base(r.Worktree)] = true
		fmt.Println()
		st, ok := repoInfo(r.Worktree)
		if !ok {
			fmt.Printf("%s%s%s  %sworktree 없음%s\n", BOLD, pad(base(r.Repo), w), RESET, RED, RESET)
			continue
		}
		cur := currentBranch(r.Worktree)
		fmt.Printf("%s%s%s  %s %s· %s%s", BOLD, pad(base(r.Repo), w), RESET, stateWords(st.Dirty, st.Ahead), MUTED, ago(st.Last), RESET)
		if cur != branch {
			if cur == "" {
				cur = "detached"
			}
			fmt.Printf("  %s%s%s", YELLOW, cur, RESET)
		}
		fmt.Println()
		if subject, _ := git(r.Worktree, "log", "-1", "--format=%s"); subject != "" {
			fmt.Printf("  %s\n", subject)
		}
		if st.Dirty > 0 {
			fmt.Printf("  %s✎%s %s%s%s\n", YELLOW, RESET, MUTED, joinSome(3, changedNames(r.Worktree)), RESET)
		}
	}

	if others := otherEntries(dir, tracked); len(others) > 0 {
		fmt.Println()
		fmt.Printf("%s이슈 폴더%s  %s\n", MUTED, RESET, joinSome(4, others))
	}
	fmt.Println()
	fmt.Printf("%s%s%s\n", MUTED, tilde(dir), RESET)
	return 0
}
