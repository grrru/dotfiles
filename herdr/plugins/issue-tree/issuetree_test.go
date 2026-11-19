package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

var testRoot string

// TestMain 은 herdr 를 stub 으로 바꾸고 HOME·WORKTREE·WORKSPACE·state·git 설정을 임시 폴더로 돌려,
// 테스트가 실제 herdr 서버나 이슈 폴더에 닿지 않게 한다.
func TestMain(m *testing.M) {
	root, err := os.MkdirTemp("", "issuetree-test.")
	if err != nil {
		panic(err)
	}
	testRoot = root
	stub := filepath.Join(root, "herdr-stub")
	os.WriteFile(stub, []byte("#!/bin/sh\necho '{\"result\":{\"panes\":[],\"workspaces\":[]}}'\n"), 0o755)
	gitcfg := filepath.Join(root, "gitconfig")
	os.WriteFile(gitcfg, []byte("[user]\n\tname = t\n\temail = t@example.invalid\n[init]\n\tdefaultBranch = main\n"), 0o644)
	for _, d := range []string{"home", "wt", "ws", "state"} {
		os.MkdirAll(filepath.Join(root, d), 0o755)
	}
	for _, k := range []string{"HERDR_SOCKET_PATH", "HERDR_PANE_ID", "HERDR_WORKSPACE_ID", "HERDR_TAB_ID",
		"HERDR_PLUGIN_CONFIG_DIR", "ISSUE_TREE_RIGHT_CMD", "XDG_STATE_HOME"} {
		os.Unsetenv(k)
	}
	os.Setenv("HERDR_BIN_PATH", stub)
	os.Setenv("HOME", filepath.Join(root, "home"))
	os.Setenv("WORKTREE", filepath.Join(root, "wt"))
	os.Setenv("WORKSPACE", filepath.Join(root, "ws"))
	os.Setenv("HERDR_PLUGIN_STATE_DIR", filepath.Join(root, "state"))
	os.Setenv("GIT_CONFIG_GLOBAL", gitcfg)
	os.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	loadConfig()
	code := m.Run()
	os.RemoveAll(root)
	os.Exit(code)
}

func mustGit(t *testing.T, dir string, args ...string) string {
	t.Helper()
	out, err := exec.Command("git", append([]string{"-C", dir}, args...)...).CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// newRepo 는 origin(bare)을 둔 레포를 $WORKSPACE 아래에 만든다.
func newRepo(t *testing.T, name string) string {
	t.Helper()
	origin := filepath.Join(testRoot, "origin", name+".git")
	repo := filepath.Join(workspaceDir, name)
	mustGit(t, testRoot, "init", "-q", "--bare", origin)
	mustGit(t, testRoot, "clone", "-q", origin, repo)
	os.WriteFile(filepath.Join(repo, "README"), []byte(name), 0o644)
	mustGit(t, repo, "add", ".")
	mustGit(t, repo, "commit", "-qm", "init")
	mustGit(t, repo, "push", "-q", "origin", "main")
	mustGit(t, repo, "remote", "set-head", "origin", "main")
	return repo
}

func TestParseIssueRef(t *testing.T) {
	cases := map[string]string{
		"123": "123", " #123 ": "123", "https://example.com/o/r/issues/77#issuecomment-1": "77",
		"https://example.com/o/r/pull/12/files": "12", "abc": "", "#": "", "": "", "https://x/o/r/wiki/3": "",
		"https://gitlab.com/g/sub/p/-/issues/5": "5",
	}
	for in, want := range cases {
		got, ok := parseIssueRef(in)
		if got != want || ok != (want != "") {
			t.Errorf("parseIssueRef(%q) = %q,%v want %q", in, got, ok, want)
		}
	}
}

func TestParseIssueRepo(t *testing.T) {
	cases := map[string]string{
		"https://example.com/o/r/issues/77#issuecomment-1": "example.com/o/r", " github.com/o/r/pull/12/files ": "github.com/o/r",
		"http://example.com/o/r/issues/7?x=1": "example.com/o/r", "123": "", "#123": "",
		"https://gitlab.com/g/sub/p/-/issues/5": "", "https://example.com/o/r/issues/7x": "", "https://x/o/r/wiki/3": "",
	}
	for in, want := range cases {
		if got := parseIssueRepo(in); got != want {
			t.Errorf("parseIssueRepo(%q) = %q want %q", in, got, want)
		}
	}
}

func TestNames(t *testing.T) {
	if got := sanitizeTag("wiz x/한글_ok-1"); got != "wiz-x_ok-1" {
		t.Errorf("sanitizeTag = %q", got)
	}
	if issueSuffix("42", "") != "42" || issueSuffix("42", "a") != "42-a" {
		t.Error("issueSuffix")
	}
	for dir, want := range map[string][3]string{
		"/w/456-fix-login": {"456", "fix-login", "fix-login"}, "/w/401": {"401", "", "401"}, "/w/notes": {"", "", "notes"},
	} {
		if got := [3]string{treeNum(dir), treeTag(dir), treeLabel(dir)}; got != want {
			t.Errorf("%s = %v want %v", dir, got, want)
		}
	}
}

func TestTrackerID(t *testing.T) {
	dir := filepath.Join(worktreeDir, "1-id")
	os.MkdirAll(dir, 0o755)
	defer os.RemoveAll(dir)
	// ID 줄이 없는 tracker 에 ID 를 넣으면 BRANCH 줄 바로 뒤에 온다.
	os.WriteFile(filepath.Join(dir, trackerName), []byte("ISSUE_NUM=1\nBRANCH=issue/1-id\nREPO\t/r/a\t"+dir+"/a_1-id\n"), 0o644)
	id := ensureTreeID(dir)
	if len(id) != 16 || ensureTreeID(dir) != id {
		t.Fatalf("ensureTreeID = %q", id)
	}
	if got := trackerLines(dir); !reflect.DeepEqual(got, []string{"ISSUE_NUM=1", "BRANCH=issue/1-id", "ID=" + id, "REPO\t/r/a\t" + dir + "/a_1-id"}) {
		t.Errorf("tracker = %q", got)
	}
	if rows := repoRows(dir); len(rows) != 1 || rows[0].Repo != "/r/a" {
		t.Errorf("repoRows = %v", rows)
	}
}

func TestConfigFile(t *testing.T) {
	cfg := filepath.Join(testRoot, "config.sh")
	os.WriteFile(cfg, []byte("# c\nISSUE_TREE_RIGHT_CMD=''\nexport ISSUE_TREE_RATIO=\"0.5\"\nISSUE_TREE_RIGHT_CWD=issue # x\nWORKTREE=~/wt2\n"), 0o644)
	saved := [4]string{rightCmd, ratio, rightCwd, worktreeDir}
	defer func() { rightCmd, ratio, rightCwd, worktreeDir = saved[0], saved[1], saved[2], saved[3] }()
	applyConfigFile(cfg)
	if rightCmd != "" || ratio != "0.5" || rightCwd != "issue" || worktreeDir != homeDir+"/wt2" {
		t.Errorf("config = %q %q %q %q", rightCmd, ratio, rightCwd, worktreeDir)
	}
}

func TestLostCommits(t *testing.T) {
	repo := newRepo(t, "lost")
	mustGit(t, repo, "branch", "issue/9")
	if n := lostCommits(repo, "refs/heads/issue/9"); n != 0 {
		t.Errorf("main 에 있는 커밋은 잃지 않는다: %d", n)
	}
	mustGit(t, repo, "checkout", "-q", "issue/9")
	os.WriteFile(filepath.Join(repo, "x"), []byte("x"), 0o644)
	mustGit(t, repo, "add", ".")
	mustGit(t, repo, "commit", "-qm", "x")
	mustGit(t, repo, "push", "-q", "origin", "issue/9")
	mustGit(t, repo, "checkout", "-q", "main")
	if n := lostCommits(repo, "refs/heads/issue/9"); n != 0 {
		t.Errorf("원격에 있으면 잃지 않는다: %d", n)
	}
	if n := lostCommits(repo, "refs/heads/issue/9", "refs/remotes/origin/issue/9"); n != 1 {
		t.Errorf("원격까지 지우면 1개를 잃는다: %d", n)
	}
	if n := lostCommits(repo, "refs/heads/none"); n != 0 {
		t.Errorf("없는 ref: %d", n)
	}
}

func TestSetupAndCleanScan(t *testing.T) {
	alpha, beta := newRepo(t, "alpha"), newRepo(t, "beta")
	dir := filepath.Join(worktreeDir, "20-scan")
	if !doSetup(dir, "20", "", "issue/20-scan", []string{alpha, beta, filepath.Join(workspaceDir, "missing")}) {
		t.Fatal("doSetup")
	}
	rows := repoRows(dir)
	if len(rows) != 2 || treeID(dir) == "" || trackerGet(dir, "BRANCH") != "issue/20-scan" {
		t.Fatalf("tracker = %v", trackerLines(dir))
	}
	// 같은 레포를 다시 더해도 tracker 에 두 번 들어가지 않는다.
	doSetup(dir, "20", "", "issue/20-scan", []string{alpha})
	if len(repoRows(dir)) != 2 {
		t.Errorf("중복 REPO 줄: %v", trackerLines(dir))
	}

	os.WriteFile(filepath.Join(rows[0].Worktree, "dirty"), []byte("d"), 0o644)
	os.WriteFile(filepath.Join(dir, "comment.md"), []byte("c"), 0o644)
	os.Symlink(rows[0].Worktree, filepath.Join(dir, "link"))
	mustGit(t, alpha, "worktree", "add", "-q", "--detach", filepath.Join(dir, "alpha_pr1"))

	cs, errText := cleanScan(dir)
	if cs == nil {
		t.Fatal(errText)
	}
	if cs.dirty != 1 || len(cs.extras) != 1 || !reflect.DeepEqual(cs.files, []string{"comment.md"}) || !reflect.DeepEqual(cs.links, []string{"link"}) {
		t.Errorf("scan = dirty %d extras %v files %v links %v", cs.dirty, cs.extras, cs.files, cs.links)
	}
	if w := cs.warnings("keep"); len(w) != 2 {
		t.Errorf("warnings = %v", w)
	}
	if _, errText := cleanScan(filepath.Join(testRoot, "ws")); errText == "" {
		t.Error("WORKTREE 밖 폴더는 정리하지 않는다")
	}

	doClean(cs, "keep")
	if exists(dir) || showRef(alpha, "refs/heads/issue/20-scan") {
		t.Error("정리 후 폴더나 브랜치가 남음")
	}
	if out := mustGit(t, alpha, "worktree", "list"); strings.Contains(out, "20-scan") {
		t.Errorf("worktree 등록이 남음: %s", out)
	}
}

func TestIssueRepoKept(t *testing.T) {
	kept, kept2 := newRepo(t, "kept"), newRepo(t, "kept2")
	// 링크로 만든 tree 는 ISSUE_REPO 를 ISSUE_NUM 바로 뒤에 둔다. ^R 처럼 번호로 레포를 더해도 남는다.
	dir := filepath.Join(worktreeDir, "40-link")
	if !doSetup(dir, "40", "example.com/o/r", "issue/40-link", []string{kept}) {
		t.Fatal("doSetup")
	}
	if got := trackerLines(dir); len(got) < 2 || got[1] != "ISSUE_REPO=example.com/o/r" {
		t.Fatalf("tracker = %q", got)
	}
	doSetup(dir, "40", "", "issue/40-link", []string{kept2})
	if got := trackerGet(dir, "ISSUE_REPO"); got != "example.com/o/r" || len(repoRows(dir)) != 2 {
		t.Errorf("tracker = %q", trackerLines(dir))
	}

	// 번호로 만든 tree 에는 ISSUE_REPO 줄이 없다.
	if rc := cmdSetupCLI([]string{"41", "--repo", "kept", "--no-open"}); rc != 0 {
		t.Fatalf("setup 41 rc=%d", rc)
	}
	dir2 := filepath.Join(worktreeDir, "41")
	before := trackerLines(dir2)
	if len(before) != 4 || trackerGet(dir2, "ISSUE_REPO") != "" {
		t.Fatalf("번호로 만든 tracker = %q", before)
	}
	// 같은 폴더라도 링크로 주면 다른 이슈라서, --repo 가 있든 없든 아무것도 바꾸지 않는다.
	for _, args := range [][]string{
		{"https://example.com/o/r/issues/41", "--no-open"},
		{"https://example.com/o/r/issues/41", "--repo", "kept2", "--no-open"},
	} {
		if rc := cmdSetupCLI(args); rc == 0 {
			t.Errorf("%v: 저장소 없는 tree 를 링크 이슈로 씀", args)
		}
	}
	if got := trackerLines(dir2); !reflect.DeepEqual(got, before) || exists(filepath.Join(dir2, "kept2_41")) || showRef(kept2, "refs/heads/issue/41") {
		t.Errorf("링크로 연 번호 tree = %q", got)
	}
	// 저장소를 지정하면 그 링크로만 찾고, 번호만으로는 찾지 않는다.
	setIssueRepo(dir2, "example.com/o/r")
	if rc := cmdSetupCLI([]string{"41", "--repo", "kept2", "--no-open"}); rc == 0 || exists(filepath.Join(dir2, "kept2_41")) {
		t.Error("번호만으로 저장소 있는 tree 에 더함")
	}
	if rc := cmdSetupCLI([]string{"https://EXAMPLE.com/o/r/issues/41", "--repo", "kept2", "--no-open"}); rc != 0 || len(repoRows(dir2)) != 2 {
		t.Errorf("같은 저장소 링크 rc=%d tracker=%q", rc, trackerLines(dir2))
	}
	if rc := cmdSetupCLI([]string{"https://example.com/x/y/issues/41", "--no-open"}); rc == 0 {
		t.Error("다른 저장소 링크로 엶")
	}

	// 링크와 --repo 로 새로 만들 때도 남는다.
	if rc := cmdSetupCLI([]string{"https://github.com/o/r/pull/42/files", "--tag", "cli", "--repo", "kept", "--no-open"}); rc != 0 {
		t.Fatalf("setup 42 rc=%d", rc)
	}
	if got := trackerGet(filepath.Join(worktreeDir, "42-cli"), "ISSUE_REPO"); got != "github.com/o/r" {
		t.Errorf("42-cli ISSUE_REPO = %q", got)
	}
}

func TestSetIssueRepo(t *testing.T) {
	dir := filepath.Join(worktreeDir, "60-edit")
	os.MkdirAll(dir, 0o755)
	defer os.RemoveAll(dir)
	base := []string{"ISSUE_NUM=60", "BRANCH=issue/60-edit", "ID=0123456789abcdef", "REPO\t/r/a\t" + dir + "/a_60-edit"}
	os.WriteFile(filepath.Join(dir, trackerName), []byte(strings.Join(base, "\n")+"\n"), 0o644)
	old := time.Now().Add(-48 * time.Hour).Truncate(time.Second)
	os.Chtimes(filepath.Join(dir, trackerName), old, old)
	withRepo := func(r string) []string {
		return append([]string{base[0], "ISSUE_REPO=" + r}, base[1:]...)
	}
	// 넣기·바꾸기·지우기 모두 다른 줄은 순서까지 그대로다.
	for _, step := range []struct {
		repo string
		want []string
	}{
		{"example.com/o/r", withRepo("example.com/o/r")},
		{"example.com/x/y", withRepo("example.com/x/y")},
		{"", base},
	} {
		if err := setIssueRepo(dir, step.repo); err != nil {
			t.Fatal(err)
		}
		if got := trackerLines(dir); !reflect.DeepEqual(got, step.want) {
			t.Errorf("setIssueRepo(%q) = %q", step.repo, got)
		}
		if fi, _ := os.Stat(filepath.Join(dir, trackerName)); !fi.ModTime().Equal(old) {
			t.Errorf("setIssueRepo(%q) 가 수정 시각을 바꿈: %v", step.repo, fi.ModTime())
		}
	}

	cases := []struct{ in, repo, problem string }{
		{"https://example.com/o/r/issues/60#issuecomment-1", "example.com/o/r", ""},
		{"https://example.com/o/r/pull/60/files", "example.com/o/r", ""},
		{" example.com/o/r ", "example.com/o/r", ""},
		{"https://example.com/o/r.git", "example.com/o/r", ""},
		{"", "", ""},
		{"https://example.com/o/r/issues/61", "", "번호 다름"},
		{"https://gitlab.com/g/sub/p/-/issues/60", "", "저장소 인식 실패"},
		{"o/r", "", "인식 실패"},
		{"example.com/o/r/tree/main", "", "인식 실패"},
	}
	for _, c := range cases {
		repo, problem := issueRepoInput(c.in, "60")
		if repo != c.repo || (c.problem == "") != (problem == "") || !strings.Contains(problem, c.problem) {
			t.Errorf("issueRepoInput(%q) = %q, %q", c.in, repo, problem)
		}
	}
}

func TestIssueMatch(t *testing.T) {
	dir := filepath.Join(worktreeDir, "50-x")
	os.MkdirAll(dir, 0o755)
	defer os.RemoveAll(dir)
	os.WriteFile(filepath.Join(dir, trackerName), []byte("ISSUE_NUM=50\nISSUE_REPO=example.com/o/r\nBRANCH=issue/50-x\n"), 0o644)
	bare := filepath.Join(worktreeDir, "50-b")
	os.MkdirAll(bare, 0o755)
	defer os.RemoveAll(bare)
	os.WriteFile(filepath.Join(bare, trackerName), []byte("ISSUE_NUM=50\nBRANCH=issue/50-b\n"), 0o644)
	s := t.TempDir()
	formPut(s, "repos", "/r/a")
	derive := func(issue, tag string) (formState, string) {
		formPut(s, "issue", issue)
		formPut(s, "tag", tag)
		var ids []string
		for _, r := range formRows(s) {
			ids = append(ids, r.id)
		}
		return formDerive(s), strings.Join(ids, " ")
	}

	// 저장소가 같으면(대소문자 무시) 기존 tree 이고, 목록에는 그 저장소의 tree 만 있다.
	if f, ids := derive("https://EXAMPLE.com/O/R/issues/50", "x"); f.Tree != dir || f.Conflict || !strings.Contains(ids, "tree:"+dir) || strings.Contains(ids, "tree:"+bare) {
		t.Errorf("같은 저장소: %+v %s", f, ids)
	}
	// 번호만 넣으면 저장소 없는 tree 만 같은 이슈다.
	if f, ids := derive("50", "b"); f.Tree != bare || f.Conflict || strings.Contains(ids, "tree:"+dir) {
		t.Errorf("번호만 · 저장소 없는 tree: %+v %s", f, ids)
	}
	// 저장소가 다르거나 한쪽에만 있으면 같은 태그는 폴더 충돌이다.
	for _, c := range [][3]string{
		{"https://example.com/z/w/issues/50", "x", "example.com/o/r#50"},
		{"50", "x", "example.com/o/r#50"},
		{"https://example.com/o/r/issues/50", "b", "저장소 없는 #50"},
	} {
		if f, _ := derive(c[0], c[1]); !f.Conflict || f.ready() || f.Tree != "" || !strings.Contains(f.ConflictWhy, c[2]) {
			t.Errorf("%s 태그 %s: %+v", c[0], c[1], f)
		}
	}
	// 태그가 다르면 새 tree 이고, 다른 이슈의 tree 는 목록에 없다.
	if f, ids := derive("https://example.com/z/w/issues/50", "y"); f.Conflict || f.Tree != "" || !f.ready() || strings.Contains(ids, "tree:") {
		t.Errorf("다른 저장소 다른 태그: %+v %s", f, ids)
	}
}

func TestFormRows(t *testing.T) {
	s := t.TempDir()
	formPut(s, "step", "issue")
	ids := func() []string {
		var out []string
		for _, r := range formRows(s) {
			out = append(out, r.id)
		}
		return out
	}
	if got := ids(); !reflect.DeepEqual(got, []string{"issue", "tag", "repos", "go"}) {
		t.Errorf("빈 폼 = %v", got)
	}
	dir := filepath.Join(worktreeDir, "30-old")
	os.MkdirAll(dir, 0o755)
	defer os.RemoveAll(dir)
	os.WriteFile(filepath.Join(dir, trackerName), []byte("ISSUE_NUM=30\nBRANCH=issue/30-old\n"), 0o644)
	formPut(s, "issue", "30")
	if got := ids(); !reflect.DeepEqual(got, []string{"issue", "tag", "tree:" + dir, "repos", "go"}) {
		t.Errorf("기존 tree 가 있는 이슈 = %v", got)
	}
	if formIndex(s, "go") != "5" {
		t.Errorf("go 위치 = %s", formIndex(s, "go"))
	}
	formCommit(s, "tag", "old")
	if f := formDerive(s); f.Tree != dir || f.Branch != "issue/30-old" || f.ready() || f.IssueRepo != "" {
		t.Errorf("같은 태그는 기존 tree 에 더한다: %+v", f)
	}
	// 저장소 없는 tree 에 링크로 주면 다른 이슈라 충돌이고, 저장소를 지정한 뒤에는 그 링크로 찾는다.
	formPut(s, "issue", "https://example.com/o/r/issues/30")
	if f := formDerive(s); f.Tree != "" || !f.Conflict || f.IssueRepo != "example.com/o/r" {
		t.Errorf("링크로 입력한 이슈 저장소: %+v", f)
	}
	setIssueRepo(dir, "example.com/o/r")
	if f := formDerive(s); f.Tree != dir || f.Conflict || f.IssueRepo != "example.com/o/r" {
		t.Errorf("저장소를 지정한 tree: %+v", f)
	}
}
