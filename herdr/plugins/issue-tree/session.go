package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// 세션 폴더는 tree 워크스페이스 오른쪽 패널(기본 claude agents)이 뜨는 폴더다. 그 패널에서 만든 Claude
// 세션이 이 폴더에서 시작한다. 정리(^X)는 이슈 폴더 안에서 도는 세션만 끄므로, main 체크아웃에서 시작한
// 세션은 정리 대상이 아니다.
//
// tree 마다 tracker 의 SESSION_CWD 에 절대 경로로 두고, 없으면 ISSUE_TREE_RIGHT_CWD 를 따른다.
// 고르는 동안에는 폴더가 바뀌어도(폼에서 태그를 고치는 등) 같은 뜻이 되게 키로 다룬다.
//
//	main:<repo>  그 레포의 main 체크아웃   issue  이슈 폴더   path:<폴더>  직접 입력한 폴더
//	default      ISSUE_TREE_RIGHT_CWD 를 따른다

// defaultSessionCwd 는 ISSUE_TREE_RIGHT_CWD 가 가리키는 폴더다. rows 는 tree 의 레포 줄이다.
func defaultSessionCwd(dir string, rows []repoRow) string {
	switch rightCwd {
	case "main":
		if len(rows) > 0 {
			return rows[0].Repo
		}
	case "worktree":
		if len(rows) > 0 {
			return rows[0].Worktree
		}
	}
	return dir
}

// rightCwdFor 는 tree 워크스페이스 오른쪽 패널의 폴더다. 정한 폴더가 없어졌으면 기본값을 쓴다.
func rightCwdFor(dir string) string {
	rows := repoRows(dir)
	for _, p := range []string{trackerGet(dir, "SESSION_CWD"), defaultSessionCwd(dir, rows)} {
		if p != "" && isDir(p) {
			return p
		}
	}
	return dir
}

type sessionChoice struct{ key, path, label string }

// sessionChoices 는 목록에 보이는 폴더다. 레포마다 main 체크아웃(tracker·고른 순서)과 이슈 폴더 순이다.
// 그 밖의 폴더(worktree 등)는 직접 입력한다.
func sessionChoices(dir string, rows []repoRow) []sessionChoice {
	var out []sessionChoice
	for _, r := range rows {
		out = append(out, sessionChoice{"main:" + r.Repo, r.Repo, base(r.Repo)})
	}
	return append(out, sessionChoice{"issue", dir, "이슈 폴더"})
}

// resolveSession 은 키를 폴더로 바꾼다. default 나 지금 레포에 없는 키는 빈 값(기본값)이다.
func resolveSession(key, dir string, rows []repoRow) string {
	if p, ok := strings.CutPrefix(key, "path:"); ok {
		return p
	}
	for _, c := range sessionChoices(dir, rows) {
		if c.key == key {
			return c.path
		}
	}
	return ""
}

// sessionKey 는 폴더의 키다. 빈 값은 default 다.
func sessionKey(path, dir string, rows []repoRow) string {
	if path == "" {
		return "default"
	}
	for _, c := range sessionChoices(dir, rows) {
		if c.path == path {
			return c.key
		}
	}
	return "path:" + path
}

// sessionText 는 세션 폴더를 사람이 읽는 말로 쓴다. path 가 비면 기본값이 가리키는 곳에 (기본)을 붙인다.
func sessionText(dir string, rows []repoRow, path string) string {
	note := ""
	if path == "" {
		path, note = defaultSessionCwd(dir, rows), " (기본)"
	}
	for _, c := range sessionChoices(dir, rows) {
		if c.path == path {
			return c.label + note
		}
	}
	for _, r := range rows {
		if r.Worktree == path {
			return "worktree · " + base(path) + note
		}
	}
	return tilde(path) + note
}

// sessionCleanNote 는 그 폴더에서 시작한 세션을 정리 때 지우는지다.
func sessionCleanNote(dir, path string) string {
	if under(path, dir) {
		return MUTED + "정리 때 세션 제거" + RESET
	}
	return YELLOW + "정리 때 세션 유지" + RESET
}

// pickSession 은 세션 폴더 목록을 띄우고 고른 키를 돌려준다. 커서는 current(없으면 첫 레포)에 둔다.
// / 나 ~ 로 시작하게 입력하면 그 폴더를 쓴다. esc 면 ok 가 false 다.
func pickSession(dir string, rows []repoRow, current, title string) (string, bool) {
	choices := sessionChoices(dir, rows)
	w := 0
	for _, c := range choices {
		w = max(w, cellWidth(c.label))
	}
	var items strings.Builder
	pos := 1
	for i, c := range choices {
		if c.key == current {
			pos = i + 1
		}
		fmt.Fprintf(&items, "%s\t%s%s  %s  %s%s%s\n", c.key, c.label, strings.Repeat(" ", w-cellWidth(c.label)),
			sessionCleanNote(dir, c.path), MUTED, tilde(c.path), RESET)
	}
	header := "↵ 선택 · / 나 ~ 로 시작하면 폴더 직접 입력 · esc 건너뛰기"
	query := ""
	if p, ok := strings.CutPrefix(current, "path:"); ok {
		query = tilde(p)
	}
	for {
		out, rc := fz(items.String(), nil,
			"--delimiter=\t", "--with-nth=2", "--no-sort", "--no-cycle", "--print-query", "--query="+query,
			"--bind=load:pos("+strconv.Itoa(pos)+")",
			"--input-label= 세션 폴더 · "+title+" ", "--input-label-pos=2",
			"--header="+header)
		if rc > 1 && rc != 130 {
			fzfFailed(rc)
			return "", false
		}
		if rc == 130 {
			return "", false
		}
		q, picked, _ := strings.Cut(out, "\n")
		q = strings.TrimSpace(q)
		if strings.HasPrefix(q, "/") || strings.HasPrefix(q, "~") {
			path := expandValue(q)
			if !isDir(path) {
				header = RED + "✗ 폴더 없음 · " + q + RESET + "\n" + MUTED + "↵ 선택 · esc 건너뛰기" + RESET
				query = q
				continue
			}
			return sessionKey(filepath.Clean(path), dir, rows), true
		}
		if rc != 0 || picked == "" {
			return "", false
		}
		return strings.SplitN(picked, "\t", 2)[0], true
	}
}

// sessionFlow 는 목록의 ^S 다. 고른 폴더를 tracker 에 쓰고 목록에 띄울 문구를 돌려준다.
func sessionFlow(dir string) string {
	rows := repoRows(dir)
	cur := trackerGet(dir, "SESSION_CWD")
	shown := cur
	if shown == "" {
		shown = defaultSessionCwd(dir, rows)
	}
	key, ok := pickSession(dir, rows, sessionKey(shown, dir, rows), base(dir))
	if !ok {
		return ""
	}
	path := resolveSession(key, dir, rows)
	if path == cur {
		return ""
	}
	if err := setSessionCwd(dir, path); err != nil {
		return FAIL + " 저장 실패 · " + err.Error()
	}
	msg := OK + " " + base(dir) + " 세션 폴더 · " + sessionText(dir, rows, path)
	if _, _, open := workspaceFor(dir); open {
		msg += " · 워크스페이스를 새로 열 때 적용"
	}
	return msg
}

// sessionArg 는 setup --session 값을 폴더로 바꾼다. issue | worktree[:<레포>] | main[:<레포>] | 폴더 경로.
// 레포를 빼면 tracker 의 첫 레포다.
func sessionArg(arg, dir string, rows []repoRow) (string, error) {
	kind, name, _ := strings.Cut(arg, ":")
	switch kind {
	case "issue":
		if name == "" {
			return dir, nil
		}
	case "worktree", "main":
		for _, r := range rows {
			if name == "" || name == base(r.Repo) {
				if kind == "main" {
					return r.Repo, nil
				}
				return r.Worktree, nil
			}
		}
		return "", fmt.Errorf("--session %s · tree 에 그 레포 없음 (%s)", arg, repoNames(dir))
	}
	if abs, err := filepath.Abs(arg); err == nil {
		if fi, err := os.Stat(abs); err == nil && fi.IsDir() {
			return abs, nil
		}
	}
	return "", fmt.Errorf("--session %s · issue, worktree[:<레포>], main[:<레포>], 폴더 경로 중 하나", arg)
}

// cellWidth 는 터미널 칸 수다. 한글과 한자, 전각 문자는 두 칸으로 센다.
func cellWidth(s string) int {
	n := 0
	for _, r := range s {
		switch {
		case r >= 0x1100 && r <= 0x115F, r >= 0x2E80 && r <= 0xA4CF, r >= 0xAC00 && r <= 0xD7A3,
			r >= 0xF900 && r <= 0xFAFF, r >= 0xFF00 && r <= 0xFF60, r >= 0xFFE0 && r <= 0xFFE6:
			n += 2
		default:
			n++
		}
	}
	return n
}
