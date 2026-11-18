package main

import (
	"crypto/rand"
	"encoding/hex"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// 이슈 tree 는 $WORKTREE/<dir>/.issue-tracker 가 있는 폴더다.
//   브랜치  issue/<번호>[-<태그>]      폴더  $WORKTREE/<번호>[-<태그>]
//   worktree  <폴더>/<레포>_<폴더 이름>  레포 후보  $WORKSPACE/*/.git
// 이미 있는 tree 에 레포를 더하거나 정리할 때는 폴더 이름이 아니라 tracker 의 ISSUE_NUM, BRANCH 를 쓴다.
// tracker 의 ID 는 tree 마다 무작위로 만든 식별자로, 그 tree 의 워크스페이스를 찾는 데 쓴다.

const trackerName = ".issue-tracker"

var (
	issueURL = regexp.MustCompile(`/(issues|pull)/([0-9]+)`)
	digits   = regexp.MustCompile(`^[0-9]+$`)
	numPart  = regexp.MustCompile(`^([0-9]+)(-|$)`)
	tagPart  = regexp.MustCompile(`^[0-9]+-(.+)$`)
)

// parseIssueRef 는 42, '#42', .../issues/42, .../pull/42 에서 이슈 번호를 꺼낸다.
func parseIssueRef(input string) (string, bool) {
	input = strings.TrimSpace(input)
	num := ""
	if strings.Contains(input, "/") {
		if m := issueURL.FindStringSubmatch(input); m != nil {
			num = m[2]
		}
	} else {
		num = strings.TrimPrefix(input, "#")
	}
	if !digits.MatchString(num) {
		return "", false
	}
	return num, true
}

// sanitizeTag 는 공백을 '-' 로 바꾸고 ASCII 영숫자, '-', '_' 만 남긴다.
func sanitizeTag(tag string) string {
	var b strings.Builder
	for _, r := range strings.ReplaceAll(tag, " ", "-") {
		if r < 128 && (r == '-' || r == '_' || r >= '0' && r <= '9' || r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func issueSuffix(num, tag string) string {
	if tag != "" {
		return num + "-" + tag
	}
	return num
}

type repoRow struct {
	Repo, Worktree string
}

func trackerLines(dir string) []string {
	data, err := os.ReadFile(filepath.Join(dir, trackerName))
	if err != nil {
		return nil
	}
	return strings.Split(strings.TrimRight(string(data), "\n"), "\n")
}

// repoRows 는 tracker 의 REPO 줄이다.
func repoRows(dir string) []repoRow {
	var rows []repoRow
	for _, line := range trackerLines(dir) {
		f := strings.Split(line, "\t")
		if len(f) >= 3 && f[0] == "REPO" {
			rows = append(rows, repoRow{f[1], f[2]})
		}
	}
	return rows
}

// trackerGet 은 KEY=VALUE 줄 중 처음 것의 값이다.
func trackerGet(dir, key string) string {
	for _, line := range trackerLines(dir) {
		if strings.HasPrefix(line, key+"=") {
			return strings.TrimPrefix(line, key+"=")
		}
	}
	return ""
}

func hasTracker(dir string) bool {
	return isFile(filepath.Join(dir, trackerName))
}

// treeID 는 tracker 의 ID 다. ID 가 없는 tree(이전에 만든 tree)는 빈 값.
func treeID(dir string) string {
	return trackerGet(dir, "ID")
}

func newID() string {
	b := make([]byte, 8)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// ensureTreeID 는 ID 를 돌려준다. 없으면 만들어 tracker 의 BRANCH 줄 뒤에 넣는다.
func ensureTreeID(dir string) string {
	if id := treeID(dir); id != "" {
		return id
	}
	id := newID()
	var out []string
	done := false
	for _, line := range trackerLines(dir) {
		out = append(out, line)
		if !done && strings.HasPrefix(line, "BRANCH=") {
			out = append(out, "ID="+id)
			done = true
		}
	}
	if !done {
		out = append(out, "ID="+id)
	}
	writeAtomic(filepath.Join(dir, trackerName), strings.Join(out, "\n")+"\n")
	return id
}

// writeTracker 는 tracker 를 통째로 쓴다.
func writeTracker(dir, num, branch, id string, rows []repoRow) error {
	var b strings.Builder
	b.WriteString("ISSUE_NUM=" + num + "\n")
	b.WriteString("BRANCH=" + branch + "\n")
	b.WriteString("ID=" + id + "\n")
	for _, r := range rows {
		b.WriteString("REPO\t" + r.Repo + "\t" + r.Worktree + "\n")
	}
	return writeAtomic(filepath.Join(dir, trackerName), b.String())
}

func treeDirs() []string {
	matches, _ := filepath.Glob(filepath.Join(worktreeDir, "*", trackerName))
	var dirs []string
	for _, m := range matches {
		if isFile(m) {
			dirs = append(dirs, filepath.Dir(m))
		}
	}
	sort.Strings(dirs)
	return dirs
}

// treesForIssue 는 tracker 의 ISSUE_NUM 이나 폴더 이름 앞 번호가 같은 tree 다.
func treesForIssue(num string) []string {
	var out []string
	for _, dir := range treeDirs() {
		if trackerGet(dir, "ISSUE_NUM") == num || treeNum(dir) == num {
			out = append(out, dir)
		}
	}
	return out
}

func treeNum(dir string) string {
	if m := numPart.FindStringSubmatch(base(dir)); m != nil {
		return m[1]
	}
	return ""
}

// treeTag 는 태그다. 태그 없이 만든 tree 는 빈 값.
func treeTag(dir string) string {
	if m := tagPart.FindStringSubmatch(base(dir)); m != nil {
		return m[1]
	}
	return ""
}

// treeLabel 은 워크스페이스 이름이다. 태그가 없으면 폴더 이름.
func treeLabel(dir string) string {
	if t := treeTag(dir); t != "" {
		return t
	}
	return base(dir)
}

func repoNames(dir string) string {
	var names []string
	for _, r := range repoRows(dir) {
		names = append(names, base(r.Repo))
	}
	return strings.Join(names, " · ")
}

// allRepos 는 $WORKSPACE 바로 아래(와 $WORKSPACE 자신)의 git 레포다.
func allRepos() []string {
	var repos []string
	if isDir(filepath.Join(workspaceDir, ".git")) {
		repos = append(repos, workspaceDir)
	}
	entries, _ := os.ReadDir(workspaceDir)
	for _, e := range entries {
		p := filepath.Join(workspaceDir, e.Name())
		if isDir(filepath.Join(p, ".git")) {
			repos = append(repos, p)
		}
	}
	sort.Strings(repos)
	return repos
}

func repoBaseNames() string {
	var names []string
	for _, r := range allRepos() {
		names = append(names, base(r))
	}
	return strings.Join(names, " ")
}
