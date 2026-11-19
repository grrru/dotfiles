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
// ISSUE_REPO 는 그 이슈의 <host>/<owner>/<repo> 로, 이슈 링크로 만들었거나 목록의 ^E 로 지정한 tree 에 있다.
// 이슈는 ISSUE_REPO 와 번호로 구분하고, ISSUE_REPO 가 없는 tree 는 번호만 넣은 이슈와 같다.
// 폴더 이름에는 저장소가 없어서, 번호가 같은 다른 이슈는 태그가 달라야 한다.

const trackerName = ".issue-tracker"

var (
	issueURL = regexp.MustCompile(`/(issues|pull)/([0-9]+)`)
	repoURL  = regexp.MustCompile(`^(?:https?://)?([^/\s]+)/([^/\s]+)/([^/\s]+)/(?:issues|pull)/[0-9]+(?:[/?#]|$)`)
	repoOnly = regexp.MustCompile(`^(?:https?://)?([^/\s]+)/([^/\s]+)/([^/\s]+?)(?:\.git)?/?$`)
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

// parseIssueRepo 는 <host>/<owner>/<repo>/(issues|pull)/<번호> 꼴 링크의 "<host>/<owner>/<repo>" 다.
// 번호만 주었거나 다른 꼴의 링크(GitLab 의 하위 그룹 등)면 빈 값.
func parseIssueRepo(input string) string {
	m := repoURL.FindStringSubmatch(strings.TrimSpace(input))
	if m == nil {
		return ""
	}
	return m[1] + "/" + m[2] + "/" + m[3]
}

// issueRepoInput 은 ^E 입력을 ISSUE_REPO 값으로 바꾼다. 번호가 num 인 이슈 링크나 <host>/<owner>/<repo> 를
// 받고, 빈 값은 지우기다. 받을 수 없으면 problem 에 까닭을 준다.
func issueRepoInput(q, num string) (issueRepo, problem string) {
	q = strings.TrimSpace(q)
	switch {
	case q == "":
		return "", ""
	case issueURL.MatchString(q):
		n, _ := parseIssueRef(q)
		r := parseIssueRepo(q)
		if r == "" {
			return "", "저장소 인식 실패 · <host>/<owner>/<repo>/issues/<번호> 꼴 아님"
		}
		if n != num {
			return "", "번호 다름 · #" + n + " (이 tree 는 #" + num + ")"
		}
		return r, ""
	}
	if m := repoOnly.FindStringSubmatch(q); m != nil {
		return m[1] + "/" + m[2] + "/" + m[3], ""
	}
	return "", "인식 실패 · 이슈 링크나 <host>/<owner>/<repo>"
}

// issueLabel 은 이슈를 <host>/<owner>/<repo>#<번호> 로, 저장소가 없으면 "저장소 없는 #<번호>" 로 쓴다.
func issueLabel(issueRepo, num string) string {
	if issueRepo == "" {
		return "저장소 없는 #" + num
	}
	return issueRepo + "#" + num
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

// trackerInsert 는 after= 로 시작하는 첫 줄 바로 뒤에 line 을 넣는다. 그런 줄이 없으면 맨 뒤에 넣는다.
func trackerInsert(dir, after, line string) {
	var out []string
	done := false
	for _, l := range trackerLines(dir) {
		out = append(out, l)
		if !done && strings.HasPrefix(l, after+"=") {
			out = append(out, line)
			done = true
		}
	}
	if !done {
		out = append(out, line)
	}
	writeAtomic(filepath.Join(dir, trackerName), strings.Join(out, "\n")+"\n")
}

// ensureTreeID 는 ID 를 돌려준다. 없으면 만들어 tracker 의 BRANCH 줄 뒤에 넣는다.
func ensureTreeID(dir string) string {
	if id := treeID(dir); id != "" {
		return id
	}
	id := newID()
	trackerInsert(dir, "BRANCH", "ID="+id)
	return id
}

// setIssueRepo 는 tracker 의 ISSUE_REPO 줄을 바꾸고 다른 줄은 순서까지 그대로 둔다. 줄이 없으면 ISSUE_NUM 줄
// 뒤에 넣고, 빈 값이면 줄을 지운다. 목록의 최근 작업순이 tracker 수정 시각을 쓰므로 그 시각은 그대로 둔다.
func setIssueRepo(dir, issueRepo string) error {
	path := filepath.Join(dir, trackerName)
	fi, statErr := os.Stat(path)
	var out []string
	done := issueRepo == ""
	for _, l := range trackerLines(dir) {
		if strings.HasPrefix(l, "ISSUE_REPO=") {
			if !done {
				out = append(out, "ISSUE_REPO="+issueRepo)
				done = true
			}
			continue
		}
		out = append(out, l)
		if !done && strings.HasPrefix(l, "ISSUE_NUM=") {
			out = append(out, "ISSUE_REPO="+issueRepo)
			done = true
		}
	}
	if !done {
		out = append(out, "ISSUE_REPO="+issueRepo)
	}
	if err := writeAtomic(path, strings.Join(out, "\n")+"\n"); err != nil {
		return err
	}
	if statErr == nil {
		os.Chtimes(path, fi.ModTime(), fi.ModTime())
	}
	return nil
}

// issueNum 은 tree 의 이슈 번호다. tracker 에 없으면 폴더 이름 앞 번호.
func issueNum(dir string) string {
	if n := trackerGet(dir, "ISSUE_NUM"); n != "" {
		return n
	}
	return treeNum(dir)
}

// writeTracker 는 tracker 를 통째로 쓴다. issueRepo 가 비면 ISSUE_REPO 줄을 쓰지 않는다.
func writeTracker(dir, num, issueRepo, branch, id string, rows []repoRow) error {
	var b strings.Builder
	b.WriteString("ISSUE_NUM=" + num + "\n")
	if issueRepo != "" {
		b.WriteString("ISSUE_REPO=" + issueRepo + "\n")
	}
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

// sameIssueRepo 는 두 이슈 저장소가 같은지다(대소문자 무시). 빈 값은 빈 값하고만 같다.
func sameIssueRepo(a, b string) bool {
	return strings.EqualFold(a, b)
}

// otherIssue 는 treeFor 가 다른 이슈의 tree 라서 쓸 수 없는 폴더에 주는 까닭의 앞부분이다.
const otherIssue = "다른 이슈"

// treeFor 는 이슈 번호와 태그가 쓰는 폴더다. 그 폴더가 같은 이슈의 tree 면 tree 가 true 이고,
// 쓸 수 없는 폴더면 conflict 에 까닭을 준다.
func treeFor(num, tag, issueRepo string) (dir string, tree bool, conflict string) {
	dir = filepath.Join(worktreeDir, issueSuffix(num, tag))
	switch {
	case hasTracker(dir):
		if r := trackerGet(dir, "ISSUE_REPO"); !sameIssueRepo(r, issueRepo) {
			return dir, false, otherIssue + " · " + issueLabel(r, num)
		}
		return dir, true, ""
	case exists(dir):
		return dir, false, "tracker 없음"
	}
	return dir, false, ""
}

// treesForIssue 는 tracker 의 ISSUE_NUM 이나 폴더 이름 앞 번호가 같고 이슈 저장소가 어긋나지 않는 tree 다.
func treesForIssue(num, issueRepo string) []string {
	var out []string
	for _, dir := range treeDirs() {
		if (trackerGet(dir, "ISSUE_NUM") == num || treeNum(dir) == num) && sameIssueRepo(trackerGet(dir, "ISSUE_REPO"), issueRepo) {
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
