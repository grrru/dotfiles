package main

import (
	"errors"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
)

// setupRepo 는 브랜치를 만들고 worktree 를 붙인다. 돌려주는 note 는 경고 한 줄이다.
// fetch 가 실패하면 마지막으로 받아 둔 origin 기준으로 만들고 경고만 남긴다.
func setupRepo(repo, branch, wp string) (string, error) {
	note := ""
	if _, _, code := gitNet(repo, "fetch", "--quiet"); code != 0 {
		note = "fetch 실패 · 기존 origin 기준"
	}
	def := defaultBranch(repo)
	if !showRef(repo, "refs/heads/"+branch) {
		if _, _, code := gitErr(repo, "branch", branch, "origin/"+def); code != 0 {
			if _, stderr, code := gitErr(repo, "branch", branch, def); code != 0 {
				return note, errors.New(errMsg(stderr))
			}
		}
	}
	if _, stderr, code := gitErr(repo, "worktree", "add", "--quiet", wp, branch); code != 0 {
		return note, errors.New(errMsg(stderr))
	}
	return note, nil
}

// doSetup 은 레포마다 브랜치와 worktree 를 만들고 tracker 를 쓴다. 하나라도 성공했으면 true.
// tracker 에는 성공한 레포만 남고, 새로 만든 폴더는 모두 실패하면 지운다. Ctrl-C 는 지금 레포까지만 하고 멈춘다.
func doSetup(dir, num, branch string, repos []string) bool {
	var entries []repoRow
	id := ""
	newDir := false
	if hasTracker(dir) {
		id = treeID(dir)
		entries = repoRows(dir)
	} else {
		newDir = true
		os.MkdirAll(dir, 0o755)
	}

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt)
	defer signal.Stop(sig)
	interrupted := false

	tty := isTTY(os.Stdout)
	eol := ""
	if tty {
		eol = "\r\x1b[K"
	}
	clearScreen()
	fmt.Printf("%s%s%s  %s→ %s/%s\n", BOLD, branch, RESET, MUTED, tilde(dir), RESET)
	fmt.Println()
	ok, failed := 0, 0
	for _, repo := range repos {
		select {
		case <-sig:
			interrupted = true
		default:
		}
		if interrupted {
			break
		}
		name := base(repo)
		wp := filepath.Join(dir, name+"_"+base(dir))
		if tty {
			fmt.Printf("  %s⋯%s %s %s준비 중%s", MUTED, RESET, name, MUTED, RESET)
		}
		if exists(wp) {
			fmt.Printf("%s  %s %s  %s기존 · %s%s\n", eol, SKIP, name, MUTED, tilde(wp), RESET)
			entries = addRow(entries, repoRow{repo, wp})
			continue
		}
		note, err := setupRepo(repo, branch, wp)
		if err == nil {
			extra := ""
			if note != "" {
				extra = "  " + YELLOW + note + RESET
			}
			fmt.Printf("%s  %s %s  %s%s%s%s\n", eol, OK, name, MUTED, tilde(wp), RESET, extra)
			entries = append(entries, repoRow{repo, wp})
			ok++
		} else {
			failed++
			msg := err.Error()
			if msg == "" {
				msg = "실패"
			}
			fmt.Printf("%s  %s %s  %s%s%s\n", eol, FAIL, name, RED, msg, RESET)
			if isDir(wp) {
				os.Remove(wp)
			}
		}
		select {
		case <-sig:
			interrupted = true
		default:
		}
	}

	if len(entries) > 0 {
		if id == "" {
			id = newID()
		}
		writeTracker(dir, num, branch, id, entries)
	} else if newDir {
		os.Remove(dir)
	}

	next := "닫기"
	if ok > 0 {
		next = "tree 열기"
	}
	if interrupted {
		pause("중단 · ↵ " + next)
	} else if failed > 0 {
		if ok == 0 {
			next = "돌아가기"
		}
		pause(fmt.Sprintf("실패 %d개 · ↵ %s", failed, next))
	}
	return ok > 0
}

// cmdSetupCLI 는 명령줄 setup 이다. 레포 이름과 워크스페이스를 모두 확인한 뒤에만 만든다.
func cmdSetupCLI(args []string) int {
	ref, tag, pane, here := "", "", "", ""
	open := true
	var want []string
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch a {
		case "--tag", "--repo", "--pane", "--here":
			if i+1 >= len(args) {
				fmt.Fprintf(os.Stderr, "%s 에 값 필요\n", a)
				return 2
			}
			i++
			switch a {
			case "--tag":
				tag = args[i]
			case "--repo":
				want = append(want, args[i])
			case "--pane":
				pane = args[i]
			case "--here":
				here = args[i]
			}
		case "--no-open":
			open = false
		default:
			if strings.HasPrefix(a, "-") {
				fmt.Fprintf(os.Stderr, "알 수 없는 옵션 · %s\n", a)
				return 2
			}
			ref = a
		}
	}
	if !requireEnv() {
		return 1
	}
	num, okNum := parseIssueRef(ref)
	if !okNum {
		fmt.Fprintf(os.Stderr, "이슈 번호 인식 실패 · '%s'\n", ref)
		return 2
	}
	if here != "" && (pane != "" || !open) {
		fmt.Fprintln(os.Stderr, "--here 는 --pane, --no-open 과 같이 쓸 수 없음")
		return 2
	}
	tag = sanitizeTag(tag)
	dir := filepath.Join(worktreeDir, issueSuffix(num, tag))
	branch := ""
	switch {
	case hasTracker(dir):
		branch = trackerGet(dir, "BRANCH")
		num = trackerGet(dir, "ISSUE_NUM")
	case exists(dir):
		fmt.Fprintf(os.Stderr, "폴더 충돌 · %s (tracker 없음)\n", tilde(dir))
		return 1
	default:
		branch = "issue/" + issueSuffix(num, tag)
		if len(want) == 0 {
			fmt.Fprintf(os.Stderr, "새 tree 는 --repo 필요 · 후보: %s\n", repoBaseNames())
			return 2
		}
	}
	var picked []string
	for _, name := range want {
		name = strings.TrimSuffix(name, "/")
		found := ""
		for _, repo := range allRepos() {
			if name == base(repo) || name == strings.TrimPrefix(repo, workspaceDir+"/") || name == repo {
				found = repo
				break
			}
		}
		if found == "" {
			fmt.Fprintf(os.Stderr, "레포 없음 · %s (후보: %s)\n", name, repoBaseNames())
			return 2
		}
		picked = append(picked, found)
	}

	if here != "" {
		if _, err := hereCheck(dir, here); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
	} else if pane != "" && paneID(pane) == "" {
		fmt.Fprintf(os.Stderr, "패널 없음 · %s\n", pane)
		return 1
	}
	if len(picked) > 0 {
		if !doSetup(dir, num, branch, picked) {
			return 1
		}
		fmt.Println()
	}
	fmt.Printf("tree       %s\n", tilde(dir))
	switch {
	case here != "":
		ws, p, err := attachHere(dir, here)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		fmt.Printf("workspace  %s (%s)\n", workspaceLabel(ws), ws)
		fmt.Printf("pane       %s\n", p)
	case open:
		ws, p, err := openTree(dir, pane)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		fmt.Printf("workspace  %s (%s)\n", workspaceLabel(ws), ws)
		if p != "" {
			fmt.Printf("pane       %s\n", p)
		}
	}
	return 0
}

func cmdCreator() int {
	if !requireEnv() {
		pause("")
		return 0
	}
	wizardNew()
	return 0
}

// addRow 는 같은 worktree 가 없을 때만 더한다.
func addRow(rows []repoRow, r repoRow) []repoRow {
	for _, x := range rows {
		if x.Worktree == r.Worktree {
			return rows
		}
	}
	return append(rows, r)
}
