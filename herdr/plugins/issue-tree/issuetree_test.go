package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
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
	}
	for in, want := range cases {
		got, ok := parseIssueRef(in)
		if got != want || ok != (want != "") {
			t.Errorf("parseIssueRef(%q) = %q,%v want %q", in, got, ok, want)
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
	// git-issue-worktree 가 쓴 ID 없는 tracker 에 ID 를 넣으면 BRANCH 줄 바로 뒤에 온다.
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
	if !doSetup(dir, "20", "issue/20-scan", []string{alpha, beta, filepath.Join(workspaceDir, "missing")}) {
		t.Fatal("doSetup")
	}
	rows := repoRows(dir)
	if len(rows) != 2 || treeID(dir) == "" || trackerGet(dir, "BRANCH") != "issue/20-scan" {
		t.Fatalf("tracker = %v", trackerLines(dir))
	}
	// 같은 레포를 다시 더해도 tracker 에 두 번 들어가지 않는다.
	doSetup(dir, "20", "issue/20-scan", []string{alpha})
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
	if f := formDerive(s); f.Tree != dir || f.Branch != "issue/30-old" || f.ready() {
		t.Errorf("같은 태그는 기존 tree 에 더한다: %+v", f)
	}
}
