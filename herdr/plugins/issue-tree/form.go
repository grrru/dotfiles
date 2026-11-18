package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// 새 tree · 레포 추가 폼.
// 한 화면에 1 이슈 · 2 태그 · 3 레포 · 만들기 줄이 차례로 있고, ↵ 는 그 줄을 확정하고 다음 줄로 내려간다.
// 이슈와 태그는 위 입력 칸에 쓰고, 레포 줄에서 ↵ 를 누르면 여러 개를 고르는 목록이 열린다.
// 상태는 임시 폴더의 파일(issue, tag, tree, repos, step, locked)에 두고, fzf 의 start·focus·enter
// 이벤트마다 form-event 가 읽고 써서 다음 fzf 동작을 돌려준다. 커서를 옮기면 떠나는 줄에 입력을 확정한다.

func formGet(s, key string) string {
	data, err := os.ReadFile(filepath.Join(s, key))
	if err != nil {
		return ""
	}
	return strings.TrimRight(string(data), "\n")
}

func formPut(s, key, val string) {
	writeAtomic(filepath.Join(s, key), val+"\n")
}

type formState struct {
	Issue, Num, Tag, Tree string
	Locked, Conflict      bool
	Suffix, Dir, Branch   string
	Have, Repos           []string
}

// formDerive 는 상태 파일에서 지금 만들 tree 를 계산한다. 태그가 기존 tree 와 같으면 그 tree 에 더한다.
func formDerive(s string) formState {
	var f formState
	f.Issue = formGet(s, "issue")
	f.Num, _ = parseIssueRef(f.Issue)
	f.Tag = sanitizeTag(formGet(s, "tag"))
	f.Tree = formGet(s, "tree")
	f.Locked = formGet(s, "locked") == "1"
	if f.Tree == "" && f.Num != "" {
		d := filepath.Join(worktreeDir, issueSuffix(f.Num, f.Tag))
		if hasTracker(d) {
			f.Tree = d
		} else if exists(d) {
			f.Conflict = true
		}
	}
	if f.Tree != "" {
		f.Dir, f.Suffix, f.Branch = f.Tree, base(f.Tree), trackerGet(f.Tree, "BRANCH")
		for _, r := range repoRows(f.Tree) {
			f.Have = append(f.Have, r.Repo)
		}
	} else if f.Num != "" {
		f.Suffix = issueSuffix(f.Num, f.Tag)
		f.Dir = filepath.Join(worktreeDir, f.Suffix)
		f.Branch = "issue/" + f.Suffix
	}
	have := map[string]bool{}
	for _, r := range f.Have {
		have[r] = true
	}
	for _, r := range lines(formGet(s, "repos")) {
		if r != "" && !have[r] {
			f.Repos = append(f.Repos, r)
		}
	}
	return f
}

func (f formState) ready() bool {
	return f.Num != "" && !f.Conflict && len(f.Repos) > 0
}

type formRow struct{ id, text string }

// formRows 는 폼의 줄이다. id 는 issue, tag, tree:<dir>, repos, go.
func formRows(s string) []formRow {
	f := formDerive(s)
	var rows []formRow
	var mark, value string

	switch {
	case f.Locked:
		mark, value = OK, "#"+f.Num
	case f.Issue == "":
		mark, value = MUTED+"1"+RESET, MUTED+"번호 · #번호 · URL"+RESET
	case f.Num == "":
		mark, value = FAIL, f.Issue+"  "+RED+"번호 인식 실패"+RESET
	default:
		mark, value = OK, BLUE+"#"+f.Num+RESET
	}
	rows = append(rows, formRow{"issue", mark + "  이슈   " + value})

	switch {
	case f.Num == "":
		mark, value = MUTED+"2"+RESET, ""
	case f.Conflict:
		mark, value = FAIL, f.Tag+"  "+RED+"폴더 충돌 · "+base(f.Dir)+"/ (tracker 없음)"+RESET
	case f.Tree != "":
		mark, value = OK, BOLD+f.Suffix+RESET+"  "+BLUE+"↺"+RESET+" 기존 tree"
	default:
		tag := f.Tag
		if tag == "" {
			tag = MUTED + "태그 없음" + RESET
		}
		mark, value = OK, tag+"  "+MUTED+"→ "+f.Branch+RESET
	}
	rows = append(rows, formRow{"tag", mark + "  태그   " + value})
	// 기존 tree 줄은 고른 뒤에도 남겨 둔다. 이동 중에 줄 수가 바뀌면 fzf 가 pos 를 이전 목록 기준으로 적용한다.
	if f.Num != "" && !f.Locked {
		for _, dir := range treesForIssue(f.Num) {
			if dir == f.Tree {
				rows = append(rows, formRow{"tree:" + dir, "         " + OK + " " + BOLD + base(dir) + RESET + "  " + MUTED + repoNames(dir) + RESET})
			} else {
				rows = append(rows, formRow{"tree:" + dir, "         " + BLUE + "↺" + RESET + " " + base(dir) + "  " + MUTED + repoNames(dir) + RESET})
			}
		}
	}

	if len(f.Repos) > 0 {
		mark, value = OK, namesOf(f.Repos)
	} else {
		mark, value = MUTED+"3"+RESET, ""
	}
	if len(f.Have) > 0 {
		value += "  " + MUTED + "+ 기존 " + namesOf(f.Have) + RESET
	}
	rows = append(rows, formRow{"repos", mark + "  레포   " + value})

	if f.ready() {
		action := "생성"
		if f.Tree != "" {
			action = "레포 추가"
		}
		rows = append(rows, formRow{"go", fmt.Sprintf("   %s%s↵ %s%s  %s%s · 레포 %d개%s", BOLD, BLUE, action, RESET, MUTED, f.Branch, len(f.Repos), RESET)})
	} else {
		rows = append(rows, formRow{"go", "   " + MUTED + "생성" + RESET})
	}
	return rows
}

func cmdFormItems(s string) int {
	for _, r := range formRows(s) {
		fmt.Printf("%s\t%s\n", r.id, r.text)
	}
	return 0
}

func formIndex(s, id string) string {
	for i, r := range formRows(s) {
		if r.id == id {
			return strconv.Itoa(i + 1)
		}
	}
	return ""
}

func formValue(s, id string) string {
	if id == "issue" || id == "tag" {
		return formGet(s, id)
	}
	return ""
}

func formLabel(id string) string {
	switch {
	case id == "issue":
		return " 이슈 "
	case id == "tag":
		return " 태그 "
	case strings.HasPrefix(id, "tree:"):
		return " 기존 tree "
	case id == "repos":
		return " 레포 "
	default:
		return " 생성 "
	}
}

// formCommit 은 떠나거나 ↵ 한 줄에 입력을 적는다. 이슈·태그가 바뀌면 고른 기존 tree 를 푼다.
func formCommit(s, id, q string) {
	if formGet(s, "locked") == "1" {
		return
	}
	if id == "issue" || id == "tag" {
		if q != formGet(s, id) {
			formPut(s, id, q)
			formPut(s, "tree", "")
		}
	}
}

// formGoto 는 그 줄로 옮기는 fzf 동작이다. change-query 는 인자에 괄호가 들어가도 되게 맨 끝에 둔다.
func formGoto(s, id string) string {
	formPut(s, "step", id)
	return fmt.Sprintf("reload-sync(%s form-items %s)+pos(%s)+change-input-label(%s)+change-query:%s",
		selfCmd, shellQuote(s), formIndex(s, id), formLabel(id), formValue(s, id))
}

// formPickRepos 는 레포 목록을 열고, 닫히면 만들기(골랐으면) 또는 레포 줄로 간다.
func formPickRepos(s string) string {
	formPut(s, "step", "repos")
	return fmt.Sprintf(`execute(%s form-repos %s)+transform(%s form-event %s after-repos "" repos)`,
		selfCmd, shellQuote(s), selfCmd, shellQuote(s))
}

func cmdFormEvent(s, event, q, id string) int {
	step := formGet(s, "step")
	switch event {
	case "start":
		if formGet(s, "locked") == "1" {
			fmt.Print(formPickRepos(s))
		}
	case "focus":
		if id == "" || id == step {
			return 0
		}
		formCommit(s, step, q)
		fmt.Print(formGoto(s, id))
	case "after-repos":
		f := formDerive(s)
		// ^R 로 연 폼은 이슈·태그가 고정이라 돌아갈 곳이 없어서, 레포 목록을 esc·q 로 닫으면 폼도 닫는다.
		if f.Locked && formGet(s, "repo-cancel") == "1" {
			fmt.Println("abort")
			return 0
		}
		if len(f.Repos) > 0 {
			fmt.Print(formGoto(s, "go"))
		} else {
			fmt.Print(formGoto(s, "repos"))
		}
	case "enter":
		formCommit(s, step, q)
		f := formDerive(s)
		switch {
		case id == "issue":
			if f.Num != "" {
				fmt.Print(formGoto(s, "tag"))
			} else {
				fmt.Print(formGoto(s, "issue"))
			}
		case id == "tag":
			if f.Conflict {
				fmt.Print(formGoto(s, "tag"))
			} else {
				fmt.Print(formPickRepos(s))
			}
		case strings.HasPrefix(id, "tree:"):
			dir := strings.TrimPrefix(id, "tree:")
			formPut(s, "tree", dir)
			formPut(s, "tag", treeTag(dir))
			fmt.Print(formPickRepos(s))
		case id == "repos":
			fmt.Print(formPickRepos(s))
		case id == "go":
			switch {
			case f.ready():
				fmt.Println("accept")
			case f.Num == "":
				fmt.Print(formGoto(s, "issue"))
			case f.Conflict:
				fmt.Print(formGoto(s, "tag"))
			default:
				fmt.Print(formPickRepos(s))
			}
		}
	}
	return 0
}

// cmdFormPreview 는 줄마다 만들어질 것이다. 입력 중인 이슈·태그는 query 로 바로 보여 준다.
func cmdFormPreview(s, id, q string) int {
	f := formDerive(s)
	switch {
	case id == "issue":
		if f.Locked {
			q = f.Issue
		}
		if q == "" {
			fmt.Printf("%s123%s\n", MUTED, RESET)
			fmt.Printf("%s#123%s\n", MUTED, RESET)
			fmt.Printf("%shttps://github.com/<owner>/<repo>/issues/123%s\n", MUTED, RESET)
			return 0
		}
		num, ok := parseIssueRef(q)
		if !ok {
			fmt.Printf("%s 번호 인식 실패\n", FAIL)
			return 0
		}
		fmt.Printf("%s%s#%s%s\n", BLUE, BOLD, num, RESET)
		fmt.Println()
		trees := treesForIssue(num)
		for _, dir := range trees {
			fmt.Printf("%s↺%s %s%s%s  %s\n", BLUE, RESET, BOLD, base(dir), RESET, repoNames(dir))
		}
		if len(trees) == 0 {
			fmt.Printf("%s＋%s 새 이슈\n", GREEN, RESET)
		}
	case id == "tag" || strings.HasPrefix(id, "tree:"):
		if id == "tag" && !f.Locked {
			f.Tag = sanitizeTag(q)
			f.Tree = formGet(s, "tree")
			if q != formGet(s, "tag") {
				f.Tree = ""
			}
			if d := filepath.Join(worktreeDir, issueSuffix(f.Num, f.Tag)); f.Tree == "" && f.Num != "" && hasTracker(d) {
				f.Tree = d
			}
		} else if strings.HasPrefix(id, "tree:") {
			f.Tree = strings.TrimPrefix(id, "tree:")
		}
		if f.Num == "" {
			fmt.Printf("%s이슈 미입력%s\n", MUTED, RESET)
			return 0
		}
		if f.Tree != "" {
			fmt.Printf("%s↺%s %s기존 tree · 레포 추가%s\n", BLUE, RESET, BOLD, RESET)
			fmt.Println()
			fmt.Printf("브랜치    %s\n", trackerGet(f.Tree, "BRANCH"))
			fmt.Printf("폴더      %s/\n", tilde(f.Tree))
			fmt.Println()
			for _, r := range repoRows(f.Tree) {
				fmt.Printf("%s %s  %s%s%s\n", OK, base(r.Repo), MUTED, base(r.Worktree), RESET)
			}
			return 0
		}
		p := issueSuffix(f.Num, f.Tag)
		fmt.Printf("%s＋%s %s새 tree%s\n", GREEN, RESET, BOLD, RESET)
		fmt.Println()
		fmt.Printf("브랜치    issue/%s\n", p)
		fmt.Printf("폴더      %s/\n", tilde(filepath.Join(worktreeDir, p)))
		fmt.Printf("worktree  <레포>_%s\n", p)
		if id == "tag" && q != "" && f.Tag != q {
			fmt.Println()
			fmt.Printf("%s태그 정리 → %s (영숫자 · - · _ 만)%s\n", YELLOW, f.Tag, RESET)
		}
		if d := filepath.Join(worktreeDir, p); exists(d) && !hasTracker(d) {
			fmt.Println()
			fmt.Printf("%s 폴더 충돌 · tracker 없음\n", FAIL)
		}
	case id == "repos" || id == "go":
		if f.Num == "" {
			fmt.Printf("%s이슈 미입력%s\n", MUTED, RESET)
			return 0
		}
		fmt.Printf("%s%s%s\n", BOLD, f.Branch, RESET)
		fmt.Printf("%s%s/%s\n", MUTED, tilde(f.Dir), RESET)
		fmt.Println()
		for _, p := range f.Repos {
			fmt.Printf("%s＋%s %s  %s%s_%s%s\n", GREEN, RESET, base(p), MUTED, base(p), f.Suffix, RESET)
		}
		for _, p := range f.Have {
			fmt.Printf("%s %s  %s기존%s\n", OK, base(p), MUTED, RESET)
		}
		if len(f.Repos) == 0 {
			fmt.Printf("%s선택 없음%s\n", MUTED, RESET)
		}
	}
	return 0
}

// 레포 목록은 vim 처럼 일반 모드로 열린다. j/k 이동, space·x 선택, g/G 처음·끝, ctrl-d/u 반 페이지,
// ↵ 완료(고른 것만, 하나도 없으면 경고하고 머문다), esc·q 닫기. / 나 i 로 검색 모드에 들어가면 그 키들을
// 풀어 글자로 입력받고, 검색 모드의 ↵ 는 현재 레포를 고르고 일반 모드로, esc 는 검색어를 지우고 일반
// 모드로 돌아간다. 모드는 상태 폴더의 repo-mode 파일에 둔다.
const (
	repoVimKeys     = "j,k,space,x,g,G,q,/,i"
	repoNormalLabel = " 레포 · j/k 이동 · space 선택 · / 검색 · ↵ 완료 "
	repoSearchLabel = " 검색 · ↵ 선택 · esc 복귀 "
	// fzf 가 transform 명령을 실행할 때 FZF_SELECT_COUNT 를 채운다.
	repoCountLabel = `transform-list-label(if [ "$FZF_SELECT_COUNT" -gt 0 ]; then echo " ✓ ${FZF_SELECT_COUNT}개 "; else echo " 선택 없음 "; fi)`
)

// cmdRepoKey 는 모드에 따라 다른 fzf 동작을 돌려준다.
func cmdRepoKey(s, key string) int {
	mode := formGet(s, "repo-mode")
	switch key {
	case "search":
		formPut(s, "repo-mode", "search")
		fmt.Printf("unbind(%s)+change-input-label(%s)\n", repoVimKeys, repoSearchLabel)
	case "enter":
		count, _ := strconv.Atoi(os.Getenv("FZF_SELECT_COUNT"))
		switch {
		case mode == "search":
			formPut(s, "repo-mode", "normal")
			fmt.Printf("toggle+clear-query+rebind(%s)+change-input-label(%s)+%s\n", repoVimKeys, repoNormalLabel, repoCountLabel)
		case count > 0:
			fmt.Println("accept")
		default:
			// fzf 의 accept 는 고른 것이 없으면 커서 줄을 돌려준다. 고른 것이 없으면 닫지 않고 경고만 띄운다.
			fmt.Printf("change-list-label( %s⚠ 선택 없음 · space 로 선택%s )\n", YELLOW, RESET)
		}
	case "esc":
		if mode == "search" {
			formPut(s, "repo-mode", "normal")
			fmt.Printf("clear-query+rebind(%s)+change-input-label(%s)\n", repoVimKeys, repoNormalLabel)
		} else {
			fmt.Println("abort")
		}
	}
	return 0
}

// cmdFormRepos 는 레포 여러 개를 고른다. 이미 고른 레포는 선택된 채로 열리고, 자주 쓴 레포가 위에 온다.
// 미리 고르기는 목록을 다 읽은 뒤(load)에 한다. start 에서는 항목이 아직 없을 수 있다.
func cmdFormRepos(s string) int {
	f := formDerive(s)
	chosen := map[string]bool{}
	for _, r := range f.Repos {
		chosen[r] = true
	}
	have := map[string]bool{}
	for _, r := range f.Have {
		have[r] = true
	}
	uses := map[string]int{}
	for _, d := range treeDirs() {
		for _, r := range repoRows(d) {
			uses[r.Repo]++
		}
	}
	repos := allRepos()
	sort.SliceStable(repos, func(a, b int) bool {
		if uses[repos[a]] != uses[repos[b]] {
			return uses[repos[a]] > uses[repos[b]]
		}
		return repos[a] < repos[b]
	})
	var cands []string
	w := 0
	for _, r := range repos {
		if have[r] {
			continue
		}
		cands = append(cands, r)
		w = max(w, len(base(r)))
	}
	if len(cands) == 0 {
		return 0
	}
	var items strings.Builder
	start := ""
	for i, r := range cands {
		fmt.Fprintf(&items, "%s\t%s  %s%s%s\n", r, pad(base(r), w), MUTED, currentBranch(r), RESET)
		if chosen[r] {
			start += fmt.Sprintf("pos(%d)+select+", i+1)
		}
	}

	key := selfCmd + " repo-key " + shellQuote(s)
	formPut(s, "repo-mode", "normal")
	out, rc := fz(items.String(), []string{"ISSUE_TREE_BRANCH=" + f.Branch, "ISSUE_TREE_DIR=" + f.Dir},
		"--multi", "--marker=✓ ", "--no-cycle", "--delimiter=\t", "--with-nth=2",
		"--input-label="+repoNormalLabel, "--input-label-pos=2",
		"--list-label= 선택 없음 ", "--list-label-pos=2",
		"--bind=load:"+start+"first+"+repoCountLabel,
		"--bind=j:down,k:up,g:first,G:last,ctrl-d:half-page-down,ctrl-u:half-page-up,q:abort",
		"--bind=space:toggle+down+"+repoCountLabel, "--bind=x:toggle+down+"+repoCountLabel,
		"--bind=tab:toggle+down+"+repoCountLabel, "--bind=shift-tab:toggle+up+"+repoCountLabel,
		"--bind=/:transform("+key+" search)", "--bind=i:transform("+key+" search)",
		"--bind=enter:transform(ISSUE_TREE_COLOR=1 "+key+" enter)", "--bind=esc:transform("+key+" esc)",
		"--preview=ISSUE_TREE_COLOR=1 "+selfCmd+" repo-preview {1}", "--preview-window=right,55%,wrap",
		"--preview-label= "+f.Branch+" ", "--preview-label-pos=2")
	if rc == 0 {
		var picked []string
		for _, line := range lines(out) {
			picked = append(picked, strings.SplitN(line, "\t", 2)[0])
		}
		writeAtomic(filepath.Join(s, "repos"), strings.Join(picked, "\n")+"\n")
		formPut(s, "repo-cancel", "")
	} else {
		formPut(s, "repo-cancel", "1")
	}
	return 0
}

// formRun 은 폼을 띄우고 만들기까지 가면 실행해서 tree 를 연다. 열었으면 true.
func formRun(s string) bool {
	title := " 새 이슈 tree "
	if formGet(s, "locked") == "1" {
		title = " " + base(formGet(s, "tree")) + " · 레포 추가 "
	}
	var items strings.Builder
	for _, r := range formRows(s) {
		items.WriteString(r.id + "\t" + r.text + "\n")
	}
	step := formGet(s, "step")
	qs := shellQuote(s)
	_, rc := fz(items.String(), nil,
		"--disabled", "--no-sort", "--no-cycle", "--info=hidden", "--delimiter=\t", "--with-nth=2",
		"--query="+formValue(s, step),
		"--input-label="+formLabel(step), "--input-label-pos=2",
		"--list-label="+title, "--list-label-pos=2",
		"--bind=start:transform("+selfCmd+" form-event "+qs+" start {q} {1})",
		"--bind=focus:transform("+selfCmd+" form-event "+qs+" focus {q} {1})",
		"--bind=enter:transform("+selfCmd+" form-event "+qs+" enter {q} {1})",
		"--preview=ISSUE_TREE_COLOR=1 "+selfCmd+" form-preview "+qs+" {1} {q}",
		"--preview-window=right,55%,wrap", "--preview-label= 생성 내용 ", "--preview-label-pos=2")
	if rc == 130 {
		return false
	}
	if rc > 1 {
		fzfFailed(rc)
		return false
	}
	f := formDerive(s)
	if !f.ready() {
		return false
	}
	if doSetup(f.Dir, f.Num, f.Branch, f.Repos) {
		if _, _, err := openTree(f.Dir, ""); err != nil {
			fmt.Fprintln(os.Stderr, err)
		}
		return true
	}
	return false
}

// wizardNew 는 빈 폼이다. 만들어 열었으면 true.
func wizardNew() bool {
	s, err := os.MkdirTemp("", "issue-tree-form.")
	if err != nil {
		return false
	}
	defer os.RemoveAll(s)
	formPut(s, "step", "issue")
	return formRun(s)
}

// wizardAdd 는 이슈·태그를 그 tree 로 고정하고 레포 목록부터 연다.
func wizardAdd(dir string) bool {
	s, err := os.MkdirTemp("", "issue-tree-form.")
	if err != nil {
		return false
	}
	defer os.RemoveAll(s)
	formPut(s, "issue", trackerGet(dir, "ISSUE_NUM"))
	formPut(s, "tag", treeTag(dir))
	formPut(s, "tree", dir)
	formPut(s, "locked", "1")
	formPut(s, "step", "repos")
	return formRun(s)
}

func cmdRepoPreview(repo string) int {
	branch, dir := os.Getenv("ISSUE_TREE_BRANCH"), os.Getenv("ISSUE_TREE_DIR")
	def := defaultBranch(repo)
	mainBranch := currentBranch(repo)
	dirty := dirtyCount(repo)
	fmt.Printf("%s▍%s%s%s%s  %s%s%s\n", BLUE, RESET, BOLD, base(repo), RESET, MUTED, tilde(repo), RESET)
	fmt.Println()
	if mainBranch == "" {
		mainBranch = "(detached)"
	}
	extra := ""
	if dirty > 0 {
		extra = fmt.Sprintf("  %s✎%d%s", YELLOW, dirty, RESET)
	}
	fmt.Printf("  main 체크아웃  %s%s\n", mainBranch, extra)
	if branch != "" {
		if showRef(repo, "refs/heads/"+branch) {
			fmt.Printf("  브랜치         %s  %s기존 로컬 브랜치 사용%s\n", branch, YELLOW, RESET)
		} else {
			fmt.Printf("  브랜치         %s  %sorigin/%s 기준 새 브랜치%s\n", branch, MUTED, def, RESET)
		}
	}
	if dir != "" {
		fmt.Printf("  worktree       %s/%s_%s\n", tilde(dir), base(repo), base(dir))
	}
	fmt.Println()
	fmt.Printf("  %sorigin/%s 최근 커밋 (fetch 전 기준)%s\n", MUTED, def, RESET)
	out, _ := git(repo, "log", "-n", "5", "--format=%h%x09%ct%x09%s", "origin/"+def)
	for _, line := range lines(out) {
		f := strings.SplitN(line, "\t", 3)
		if len(f) < 3 {
			continue
		}
		ts, _ := strconv.ParseInt(f[1], 10, 64)
		fmt.Printf("  %s%s%s %s %s· %s%s\n", MUTED, f[0], RESET, f[2], MUTED, ago(ts), RESET)
	}
	return 0
}
