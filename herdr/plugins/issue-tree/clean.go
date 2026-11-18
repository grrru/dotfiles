package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type cleanRow struct {
	repo, wt                    string
	exists                      bool
	dirty, lostKeep, lostDelete int
	onMain                      bool
	ignored                     int
}

type cleanExtra struct {
	sub, repo   string
	dirty, lost int
}

type cleanPlan struct {
	dir, branch                 string
	rows                        []cleanRow
	extras                      []cleanExtra
	files, links, agents        []string
	repos                       []string
	ws, wsLabel                 string
	wsClose                     bool
	dirty, lostKeep, lostDelete int
}

// cleanScan 은 정리 계획을 만든다. 정리해도 되는 tree 가 아니면 오류 문구를 돌려준다.
// 잃는 커밋은 지울 브랜치에서만 닿고 다른 브랜치·태그·원격 ref 로는 닿지 않는 커밋이다.
func cleanScan(dir string) (*cleanPlan, string) {
	cs := &cleanPlan{dir: dir}
	parent, err1 := filepath.EvalSymlinks(filepath.Dir(dir))
	wt, err2 := filepath.EvalSymlinks(worktreeDir)
	if !hasTracker(dir) || err1 != nil || err2 != nil || parent != wt {
		return nil, fmt.Sprintf("정리 불가 · $WORKTREE 바로 아래 이슈 tree 아님 (%s)", tilde(dir))
	}
	cs.branch = trackerGet(dir, "BRANCH")
	if cs.branch == "" {
		return nil, "정리 불가 · tracker 에 BRANCH 없음"
	}

	tracked := map[string]bool{}
	seen := map[string]bool{}
	for _, r := range repoRows(dir) {
		if !strings.HasPrefix(r.Worktree, dir+"/") {
			return nil, fmt.Sprintf("정리 불가 · 이슈 폴더 밖 worktree (%s)", tilde(r.Worktree))
		}
		tracked[base(r.Worktree)] = true
		row := cleanRow{repo: r.Repo, wt: r.Worktree}
		if isDir(r.Worktree) {
			row.exists = true
			row.dirty = dirtyCount(r.Worktree)
			out, _ := git(r.Worktree, "--no-optional-locks", "status", "--porcelain", "--ignored")
			for _, line := range lines(out) {
				if strings.HasPrefix(line, "!!") {
					row.ignored++
				}
			}
		}
		if isDir(r.Repo) {
			row.lostKeep = lostCommits(r.Repo, "refs/heads/"+cs.branch)
			row.lostDelete = lostCommits(r.Repo, "refs/heads/"+cs.branch, "refs/remotes/origin/"+cs.branch)
			row.onMain = currentBranch(r.Repo) == cs.branch
		}
		cs.rows = append(cs.rows, row)
		cs.dirty += row.dirty
		if !row.onMain {
			cs.lostKeep += row.lostKeep
			cs.lostDelete += row.lostDelete
		}
		if !seen[r.Repo] {
			seen[r.Repo] = true
			cs.repos = append(cs.repos, r.Repo)
		}
	}

	// tracker 밖의 항목: linked checkout(.git 파일), 링크, 그 밖의 파일과 폴더
	for _, name := range otherEntries(dir, tracked) {
		sub := filepath.Join(dir, strings.TrimSuffix(name, "/"))
		fi, err := os.Lstat(sub)
		if err != nil {
			continue
		}
		if fi.Mode()&os.ModeSymlink != 0 {
			cs.links = append(cs.links, base(sub))
			continue
		}
		if fi.IsDir() && isFile(filepath.Join(sub, ".git")) {
			if common, code := git(sub, "rev-parse", "--path-format=absolute", "--git-common-dir"); code == 0 {
				lost, _ := git(sub, "rev-list", "--count", "HEAD", "--not", "--branches", "--tags", "--remotes")
				cs.extras = append(cs.extras, cleanExtra{sub, strings.TrimSuffix(common, "/.git"), dirtyCount(sub), atoi(lost)})
				continue
			}
		}
		cs.files = append(cs.files, name)
	}

	// 워크스페이스: 토큰이 붙은 워크스페이스는 그 tree 의 것이라 닫는다. 경로로 추정한 워크스페이스는
	// 패널이 모두 이슈 폴더나 tracker 레포 main 체크아웃 안에 있을 때만 닫는다.
	if ws, how, ok := workspaceFor(dir); ok {
		cs.ws, cs.wsLabel, cs.wsClose = ws, workspaceLabel(ws), true
		for _, p := range wsState.panes {
			if p.WorkspaceID != ws {
				continue
			}
			if how == "cwd" {
				okPane := under(p.Cwd, dir)
				for _, rp := range cs.repos {
					if under(p.Cwd, rp) {
						okPane = true
					}
				}
				if !okPane {
					cs.wsClose = false
				}
			}
			if p.Agent != "" {
				cs.agents = append(cs.agents, p.Agent)
			}
		}
	}
	return cs, ""
}

// warnings 는 되돌릴 수 없이 사라지는 것들이다. 비어 있으면 확인 입력 없이 지운다.
func (cs *cleanPlan) warnings(mode string) []string {
	extraDirty, extraLost := 0, 0
	for _, e := range cs.extras {
		extraDirty += e.dirty
		extraLost += e.lost
	}
	var warn []string
	if cs.dirty+extraDirty > 0 {
		warn = append(warn, fmt.Sprintf("커밋 안 한 변경 %d개", cs.dirty+extraDirty))
	}
	lost := cs.lostKeep
	if mode == "delete" {
		lost = cs.lostDelete
	}
	if lost+extraLost > 0 {
		warn = append(warn, fmt.Sprintf("다른 곳에 없는 커밋 %d개", lost+extraLost))
	}
	if len(cs.files) > 0 {
		head := cs.files
		if len(head) > 3 {
			head = head[:3]
		}
		more := ""
		if len(cs.files) > 3 {
			more = " …"
		}
		warn = append(warn, fmt.Sprintf("이슈 폴더 항목 %d개 (%s%s)", len(cs.files), strings.Join(head, " "), more))
	}
	return warn
}

// cmdCleanPlan 은 정리 계획 미리보기다 (mode: cancel | keep | delete).
func cmdCleanPlan(dir, mode string) int {
	if mode == "" {
		mode = "keep"
	}
	cs, errText := cleanScan(dir)
	if cs == nil {
		fmt.Printf("%s %s\n", FAIL, errText)
		return 0
	}
	if mode == "cancel" {
		fmt.Printf("%s변경 없이 목록으로%s\n", MUTED, RESET)
		fmt.Println()
	}
	fmt.Printf("%s삭제 대상%s  %s%s/%s\n", MUTED, RESET, BOLD, tilde(dir), RESET)

	w := 0
	for _, r := range cs.rows {
		w = max(w, len(base(r.repo)))
	}
	for _, e := range cs.extras {
		w = max(w, len(base(e.sub)))
	}

	fmt.Println()
	fmt.Printf("%sworktree%s\n", MUTED, RESET)
	for _, r := range cs.rows {
		if !r.exists {
			fmt.Printf("  %s %s  %sworktree 없음 · tracker 항목만 삭제%s\n", SKIP, pad(base(r.repo), w), MUTED, RESET)
			continue
		}
		if r.dirty > 0 {
			fmt.Printf("  %s %s  %s✎%d 커밋 안 한 변경%s", FAIL, pad(base(r.repo), w), YELLOW, r.dirty, RESET)
		} else {
			fmt.Printf("  %s %s  %s%s%s", FAIL, pad(base(r.repo), w), MUTED, base(r.wt), RESET)
		}
		if r.ignored > 0 {
			fmt.Printf("  %s· gitignore 항목 %d개 포함%s", MUTED, r.ignored, RESET)
		}
		fmt.Println()
	}
	for _, e := range cs.extras {
		line := fmt.Sprintf("  %s %s  %stracker 밖 checkout · %s%s", FAIL, pad(base(e.sub), w), MUTED, base(e.repo), RESET)
		if e.dirty > 0 {
			line += fmt.Sprintf("  %s✎%d 커밋 안 한 변경%s", YELLOW, e.dirty, RESET)
		}
		if e.lost > 0 {
			line += fmt.Sprintf("  %s다른 곳에 없는 커밋 %d개%s", YELLOW, e.lost, RESET)
		}
		fmt.Println(line)
	}

	fmt.Println()
	fmt.Printf("%s브랜치%s %s\n", MUTED, RESET, cs.branch)
	for _, r := range cs.rows {
		if r.onMain {
			fmt.Printf("  %s %s  %s유지 · main 체크아웃이 이 브랜치%s\n", SKIP, pad(base(r.repo), w), YELLOW, RESET)
			continue
		}
		lost := r.lostKeep
		remote := " " + MUTED + "· 원격 유지" + RESET
		if mode == "delete" {
			lost, remote = r.lostDelete, " · 원격"
		}
		fmt.Printf("  %s %s  로컬%s", FAIL, pad(base(r.repo), w), remote)
		if lost > 0 {
			fmt.Printf("  %s다른 곳에 없는 커밋 %d개%s", YELLOW, lost, RESET)
		}
		fmt.Println()
	}

	if len(cs.files)+len(cs.links) > 0 {
		fmt.Println()
		fmt.Printf("%s이슈 폴더 다른 항목%s\n", MUTED, RESET)
		if len(cs.files) > 0 {
			fmt.Printf("  %s %s%s%s\n", FAIL, YELLOW, strings.Join(cs.files, " · "), RESET)
		}
		if len(cs.links) > 0 {
			fmt.Printf("  %s %s링크 %s%s\n", FAIL, MUTED, strings.Join(cs.links, " · "), RESET)
		}
	}

	fmt.Println()
	fmt.Printf("%s워크스페이스%s\n", MUTED, RESET)
	label := cs.wsLabel
	if label == "" {
		label = cs.ws
	}
	switch {
	case cs.ws == "":
		fmt.Printf("  %s %s워크스페이스 없음%s\n", SKIP, MUTED, RESET)
	case cs.wsClose:
		agents := ""
		if len(cs.agents) > 0 {
			agents = fmt.Sprintf(" %s· %s 종료%s", YELLOW, strings.Join(cs.agents, " "), RESET)
		}
		fmt.Printf("  %s %s 닫기%s\n", FAIL, label, agents)
	default:
		fmt.Printf("  %s %s 유지 %s· 이슈 폴더 밖 패널%s\n", SKIP, label, MUTED, RESET)
	}
	return 0
}

// cleanFlow 는 확인을 받고 정리한다. 정리했으면 true.
func cleanFlow(dir string) bool {
	cs, errText := cleanScan(dir)
	if cs == nil {
		clearScreen()
		fmt.Printf("%s %s\n", FAIL, errText)
		pause("↵ 돌아가기")
		return false
	}
	name := base(dir)
	qd := shellQuote(dir)
	out, rc := fz("cancel\t취소\nkeep\t정리 · 원격 브랜치 유지\ndelete\t정리 · 원격 브랜치 삭제\n", nil,
		"--delimiter=\t", "--with-nth=2", "--no-sort", "--disabled",
		"--input-label= 정리 · "+name+" ", "--input-label-pos=2",
		"--header=↑↓ 선택 · ↵ 실행 · esc 취소",
		"--preview=ISSUE_TREE_COLOR=1 "+selfCmd+" clean-plan "+qd+" {1}",
		"--preview-window=right,62%,wrap", "--preview-label= 정리 내용 ", "--preview-label-pos=2")
	if rc > 1 && rc != 130 {
		fzfFailed(rc)
		return false
	}
	mode := strings.SplitN(out, "\t", 2)[0]
	if rc != 0 || (mode != "keep" && mode != "delete") {
		return false
	}

	if warn := cs.warnings(mode); len(warn) > 0 {
		header := YELLOW + "⚠ 복구 불가" + RESET
		for _, w := range warn {
			header += "\n  " + w
		}
		out, rc := fz("", nil, "--disabled", "--print-query",
			"--input-label= 확인 · "+name+" 입력 시 삭제 ", "--input-label-pos=2",
			"--header="+header,
			"--preview=ISSUE_TREE_COLOR=1 "+selfCmd+" clean-plan "+qd+" "+mode,
			"--preview-window=right,62%,wrap", "--preview-label= 정리 내용 ", "--preview-label-pos=2")
		if rc > 1 && rc != 130 {
			fzfFailed(rc)
			return false
		}
		if rc == 130 {
			return false
		}
		if strings.SplitN(out, "\n", 2)[0] != name {
			clearScreen()
			fmt.Printf("%s 입력 불일치 · 삭제 취소\n", SKIP)
			pause("↵ 돌아가기")
			return false
		}
	}
	doClean(cs, mode)
	return true
}

// doClean 은 계획대로 지운다. 지우다 실패하면 이슈 폴더는 남긴다. popup 을 연 워크스페이스를 닫으면
// popup 도 같이 끝나서, 워크스페이스는 다른 정리를 마친 뒤 맨 끝에 닫는다.
func doClean(cs *cleanPlan, mode string) {
	clearScreen()
	fmt.Printf("%s정리%s  %s%s/%s\n", BOLD, RESET, MUTED, tilde(cs.dir), RESET)
	fmt.Println()
	failed := 0

	for _, r := range cs.rows {
		if !isDir(r.repo) {
			fmt.Printf("  %s %s  %s레포 없음 · 건너뜀%s\n", SKIP, base(r.repo), MUTED, RESET)
			continue
		}
		listed, _ := git(r.repo, "worktree", "list", "--porcelain")
		registered := false
		for _, line := range lines(listed) {
			if line == "worktree "+r.wt {
				registered = true
			}
		}
		if exists(r.wt) || registered {
			if _, stderr, code := gitErr(r.repo, "worktree", "remove", "--force", r.wt); code == 0 {
				fmt.Printf("  %s %s  worktree 제거\n", OK, base(r.repo))
			} else {
				fmt.Printf("  %s %s  worktree  %s%s%s\n", FAIL, base(r.repo), RED, errMsg(stderr), RESET)
				failed++
			}
		}
	}
	for _, e := range cs.extras {
		if _, stderr, code := gitErr(e.repo, "worktree", "remove", "--force", e.sub); code == 0 {
			fmt.Printf("  %s %s  worktree 제거 %s(%s)%s\n", OK, base(e.sub), MUTED, base(e.repo), RESET)
		} else {
			fmt.Printf("  %s %s  %s%s%s\n", FAIL, base(e.sub), RED, errMsg(stderr), RESET)
			failed++
		}
	}

	if failed == 0 {
		os.RemoveAll(cs.dir)
		fmt.Printf("  %s 이슈 폴더 삭제\n", OK)
	} else {
		fmt.Printf("  %s %s이슈 폴더 유지 · worktree 제거 실패%s\n", SKIP, YELLOW, RESET)
	}

	for _, rp := range cs.repos {
		if isDir(rp) {
			git(rp, "worktree", "prune")
		}
	}
	for _, e := range cs.extras {
		git(e.repo, "worktree", "prune")
	}

	for _, r := range cs.rows {
		if !isDir(r.repo) {
			continue
		}
		if r.onMain {
			fmt.Printf("  %s %s  브랜치 유지 %s(main 체크아웃이 이 브랜치)%s\n", SKIP, base(r.repo), MUTED, RESET)
		} else if showRef(r.repo, "refs/heads/"+cs.branch) {
			if _, stderr, code := gitErr(r.repo, "branch", "-D", cs.branch); code == 0 {
				fmt.Printf("  %s %s  로컬 브랜치 삭제\n", OK, base(r.repo))
			} else {
				fmt.Printf("  %s %s  로컬 브랜치  %s%s%s\n", FAIL, base(r.repo), RED, errMsg(stderr), RESET)
				failed++
			}
		}
		if mode == "delete" {
			_, stderr, code := gitNet(r.repo, "ls-remote", "--exit-code", "--heads", "origin", cs.branch)
			switch {
			case code == 2:
				fmt.Printf("  %s %s  %s원격 브랜치 없음%s\n", SKIP, base(r.repo), MUTED, RESET)
			case code != 0:
				fmt.Printf("  %s %s  원격 확인 실패  %s%s%s\n", FAIL, base(r.repo), RED, errMsg(stderr), RESET)
				failed++
			default:
				if _, stderr, code := gitNet(r.repo, "push", "--quiet", "origin", "--delete", cs.branch); code == 0 {
					fmt.Printf("  %s %s  원격 브랜치 삭제\n", OK, base(r.repo))
				} else {
					fmt.Printf("  %s %s  원격 브랜치  %s%s%s\n", FAIL, base(r.repo), RED, errMsg(stderr), RESET)
					failed++
				}
			}
		}
	}

	if failed > 0 {
		next := "목록으로"
		if cs.wsClose && cs.ws != "" {
			next = "워크스페이스 닫고 목록으로"
		}
		pause(fmt.Sprintf("실패 %d개 · ↵ %s", failed, next))
	}
	saveTags()
	if cs.ws != "" && cs.wsClose {
		if _, stderr, code := run("", nil, herdrBin, "workspace", "close", cs.ws); code != 0 {
			label := cs.wsLabel
			if label == "" {
				label = cs.ws
			}
			fmt.Printf("  %s 워크스페이스 %s  %s%s%s\n", FAIL, label, RED, errMsg(stderr), RESET)
			pause("↵ 목록으로")
		}
	}
}
