package main

import (
	"os/exec"
	"strconv"
	"strings"
)

func showRef(repo, ref string) bool {
	_, code := git(repo, "show-ref", "--verify", "--quiet", ref)
	return code == 0
}

func currentBranch(dir string) string {
	out, _ := git(dir, "branch", "--show-current")
	return out
}

func defaultBranch(repo string) string {
	ref, code := git(repo, "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD")
	if code != 0 || ref == "" {
		out, _ := git(repo, "for-each-ref", "--format=%(refname:short)", "refs/remotes/origin/main", "refs/remotes/origin/master")
		ref = ""
		if ls := lines(out); len(ls) > 0 {
			ref = ls[0]
		}
	}
	ref = strings.TrimPrefix(ref, "origin/")
	if ref == "" {
		return "main"
	}
	return ref
}

func atoi(s string) int {
	n, _ := strconv.Atoi(strings.TrimSpace(s))
	return n
}

func dirtyCount(wt string) int {
	out, _ := git(wt, "--no-optional-locks", "status", "--porcelain")
	return len(lines(out))
}

type repoState struct {
	Dirty, Ahead int
	Last         int64
}

// repoInfo 는 변경 파일 수, push 안 된 커밋 수, 마지막 커밋 시각이다. worktree 가 없으면 ok=false.
// upstream 이 없으면 origin 기본 브랜치 이후 커밋을 push 안 된 커밋으로 센다.
func repoInfo(wt string) (repoState, bool) {
	if !isDir(wt) {
		return repoState{}, false
	}
	var st repoState
	st.Dirty = dirtyCount(wt)
	if _, code := git(wt, "rev-parse", "-q", "--verify", "@{upstream}"); code == 0 {
		out, _ := git(wt, "rev-list", "--count", "@{upstream}..HEAD")
		st.Ahead = atoi(out)
	} else {
		baseRef, code := git(wt, "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD")
		if code != 0 || baseRef == "" {
			baseRef = "origin/main"
		}
		out, _ := git(wt, "rev-list", "--count", baseRef+"..HEAD")
		st.Ahead = atoi(out)
	}
	out, _ := git(wt, "log", "-1", "--format=%ct")
	n, _ := strconv.ParseInt(strings.TrimSpace(out), 10, 64)
	st.Last = n
	return st, true
}

// changedNames 는 바뀐 파일 이름이다 (폴더는 끝에 /).
func changedNames(wt string) []string {
	out, _ := git(wt, "--no-optional-locks", "status", "--porcelain")
	var names []string
	for _, line := range lines(out) {
		if len(line) < 3 {
			continue
		}
		p := line[3:]
		if i := strings.LastIndex(p, " -> "); i >= 0 {
			p = p[i+4:]
		}
		if len(p) >= 2 && p[0] == '"' && p[len(p)-1] == '"' {
			p = p[1 : len(p)-1]
		}
		if strings.HasSuffix(p, "/") {
			names = append(names, base(strings.TrimSuffix(p, "/"))+"/")
		} else {
			names = append(names, base(p))
		}
	}
	return names
}

// lostCommits 는 지울 ref 에서만 닿고 다른 브랜치·태그·원격 ref 로는 닿지 않는 커밋 수다.
func lostCommits(repo string, refs ...string) int {
	var gone []string
	for _, r := range refs {
		if showRef(repo, r) {
			gone = append(gone, r)
		}
	}
	if len(gone) == 0 {
		return 0
	}
	all, _ := git(repo, "for-each-ref", "--format=%(refname)", "refs/heads", "refs/remotes", "refs/tags")
	var keep strings.Builder
	for _, r := range lines(all) {
		skip := false
		for _, g := range gone {
			if r == g {
				skip = true
			}
		}
		if !skip {
			// rev-list 의 --not 은 --stdin 으로 받은 ref 에 적용되지 않아서 남는 ref 마다 ^ 를 붙인다.
			keep.WriteString("^" + r + "\n")
		}
	}
	cmd := exec.Command("git", append([]string{"-C", repo, "rev-list", "--count"}, append(gone, "--stdin")...)...)
	cmd.Stdin = strings.NewReader(keep.String())
	out, err := cmd.Output()
	if err != nil {
		return 0
	}
	return atoi(string(out))
}
