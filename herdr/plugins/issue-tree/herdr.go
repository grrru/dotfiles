package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// herdrJSON 은 herdr 명령을 실행해 JSON 응답을 v 에 읽는다.
func herdrJSON(v any, args ...string) error {
	out, stderr, code := run("", nil, herdrBin, args...)
	if code != 0 {
		return fmt.Errorf("herdr %s: %s", strings.Join(args, " "), strings.TrimSpace(stderr))
	}
	if v == nil {
		return nil
	}
	return json.Unmarshal([]byte(out), v)
}

type paneInfo struct {
	PaneID        string `json:"pane_id"`
	WorkspaceID   string `json:"workspace_id"`
	TabID         string `json:"tab_id"`
	Cwd           string `json:"cwd"`
	ForegroundCwd string `json:"foreground_cwd"`
	Agent         string `json:"agent"`
}

type workspaceInfo struct {
	WorkspaceID string            `json:"workspace_id"`
	Label       string            `json:"label"`
	ActiveTabID string            `json:"active_tab_id"`
	Tokens      map[string]string `json:"tokens"`
}

func paneList(ws string) []paneInfo {
	var resp struct {
		Result struct {
			Panes []paneInfo `json:"panes"`
		} `json:"result"`
	}
	args := []string{"pane", "list"}
	if ws != "" {
		args = append(args, "--workspace", ws)
	}
	if herdrJSON(&resp, args...) != nil {
		return nil
	}
	return resp.Result.Panes
}

func workspaceList() []workspaceInfo {
	var resp struct {
		Result struct {
			Workspaces []workspaceInfo `json:"workspaces"`
		} `json:"result"`
	}
	if herdrJSON(&resp, "workspace", "list") != nil {
		return nil
	}
	return resp.Result.Workspaces
}

func workspaceGet(ws string) (workspaceInfo, bool) {
	var resp struct {
		Result struct {
			Workspace workspaceInfo `json:"workspace"`
		} `json:"result"`
	}
	if herdrJSON(&resp, "workspace", "get", ws) != nil {
		return workspaceInfo{}, false
	}
	return resp.Result.Workspace, true
}

func workspaceLabel(ws string) string {
	w, _ := workspaceGet(ws)
	return w.Label
}

// paneID 는 패널 ID(옮긴 뒤의 옛 ID 별칭 포함)를 지금 ID 로 바꾼다.
func paneID(id string) string {
	var resp struct {
		Result struct {
			Pane paneInfo `json:"pane"`
		} `json:"result"`
	}
	if herdrJSON(&resp, "pane", "get", id) != nil {
		return ""
	}
	return resp.Result.Pane.PaneID
}

func under(path, dir string) bool {
	return path != "" && (path == dir || strings.HasPrefix(path, dir+"/"))
}

func wsOf(pane string) string {
	if i := strings.Index(pane, ":"); i >= 0 {
		return pane[:i]
	}
	return pane
}

// 이슈 tree 의 워크스페이스는 workspace metadata 토큰 issue_tree=<tracker ID> 로 표시한다.
// 토큰은 herdr 서버를 재시작하면 사라져서, 같은 목록을 플러그인 state 폴더의 workspaces.tsv 에 두고
// startup hook(restore-tags)이 다시 붙인다. 워크스페이스가 어디서 닫히든 workspace.closed event hook
// (sync-tags)이 목록을 다시 써서, 닫힌 워크스페이스 ID 가 남았다가 재사용된 ID 에 붙지 않게 한다.
// 어떤 tracker 에도 없는 ID 의 토큰은 토큰이 없는 것으로 본다.

// wsState 는 패널 cwd 와 워크스페이스 토큰을 프로세스마다 한 번만 읽어 둔다.
var wsState struct {
	loaded bool
	panes  []paneInfo
	tags   []workspaceInfo
	ids    map[string]bool
}

func wsLoad() {
	if wsState.loaded {
		return
	}
	wsState.ids = map[string]bool{}
	for _, dir := range treeDirs() {
		if id := treeID(dir); id != "" {
			wsState.ids[id] = true
		}
	}
	wsState.panes = paneList("")
	wsState.tags = workspaceList()
	wsState.loaded = true
}

func wsReload() {
	wsState.loaded = false
	wsLoad()
}

func validID(id string) bool {
	return id != "" && wsState.ids[id]
}

func wsTag(ws string) (string, bool) {
	for _, w := range wsState.tags {
		if w.WorkspaceID == ws {
			return w.Tokens[tagToken], true
		}
	}
	return "", false
}

// wsTagged 는 지금 있는 tree 의 ID 토큰이 붙은 워크스페이스인지다.
func wsTagged(ws string) bool {
	tag, _ := wsTag(ws)
	return validID(tag)
}

// workspaceFor 는 그 tree 의 워크스페이스와 찾은 방법(tag | cwd)이다.
// 토큰이 붙은 워크스페이스가 우선이고, 토큰이 없는 워크스페이스만 이슈 폴더 안 패널 cwd 로 추정한다.
func workspaceFor(dir string) (ws, how string, ok bool) {
	dir = strings.TrimSuffix(dir, "/")
	id := treeID(dir)
	wsLoad()
	if id != "" {
		for _, w := range wsState.tags {
			if w.WorkspaceID != "" && w.Tokens[tagToken] == id {
				return w.WorkspaceID, "tag", true
			}
		}
	}
	real, err := filepath.EvalSymlinks(dir)
	if err != nil {
		real = dir
	}
	for _, p := range wsState.panes {
		if p.WorkspaceID == "" || wsTagged(p.WorkspaceID) {
			continue
		}
		if under(p.Cwd, dir) || under(p.ForegroundCwd, dir) || under(p.Cwd, real) || under(p.ForegroundCwd, real) {
			return p.WorkspaceID, "cwd", true
		}
	}
	return "", "", false
}

func reportTag(ws, id string) {
	run("", nil, herdrBin, "workspace", "report-metadata", ws, "--source", tagSource, "--token", tagToken+"="+id)
}

// tagWorkspace 는 워크스페이스에 tree 토큰을 붙이고 state 파일을 맞춘다.
func tagWorkspace(ws, dir string) {
	reportTag(ws, ensureTreeID(dir))
	saveTags()
}

// saveTags 는 지금 붙어 있는 토큰 중 tree 가 남아 있는 것만 state 파일에 쓴다.
func saveTags() {
	os.MkdirAll(stateDir, 0o755)
	wsReload()
	var b strings.Builder
	for _, w := range wsState.tags {
		if id := w.Tokens[tagToken]; validID(id) {
			b.WriteString(w.WorkspaceID + "\t" + id + "\n")
		}
	}
	writeAtomic(filepath.Join(stateDir, "workspaces.tsv"), b.String())
}

// cmdRestoreTags (startup hook) 는 서버가 복원한 워크스페이스에 state 파일의 토큰을 다시 붙인다.
func cmdRestoreTags() int {
	data, err := os.ReadFile(filepath.Join(stateDir, "workspaces.tsv"))
	if err != nil || worktreeDir == "" {
		return 0
	}
	wsLoad()
	for _, line := range lines(strings.TrimRight(string(data), "\n")) {
		f := strings.SplitN(line, "\t", 2)
		if len(f) != 2 {
			continue
		}
		if _, ok := wsTag(f[0]); !ok || !validID(f[1]) {
			continue
		}
		reportTag(f[0], f[1])
	}
	saveTags()
	return 0
}

// openTree 는 tree 워크스페이스로 전환하고, 없으면 만든다. pane 을 주면 오른쪽 패널을 새로 띄우지 않고
// 그 패널을 옮겨 온다. 결과 워크스페이스와 옮긴 패널을 돌려준다.
func openTree(dir, pane string) (string, string, error) {
	dir = strings.TrimSuffix(dir, "/")
	if !hasTracker(dir) {
		return "", "", fmt.Errorf("이슈 tree 아님 (.issue-tracker 없음) · %s", dir)
	}
	if pane != "" {
		real := paneID(pane)
		if real == "" {
			return "", "", fmt.Errorf("패널 없음 · %s", pane)
		}
		pane = real
	}
	if ws, how, ok := workspaceFor(dir); ok {
		// 경로로 찾은 워크스페이스는 이때 토큰을 붙여 다음부터 토큰으로 찾는다.
		if how == "cwd" {
			tagWorkspace(ws, dir)
		}
		if pane != "" && wsOf(pane) != ws {
			w, _ := workspaceGet(ws)
			root := ""
			for _, p := range paneList(ws) {
				if p.TabID == w.ActiveTabID {
					root = p.PaneID
					break
				}
			}
			return ws, movePane(pane, w.ActiveTabID, root), nil
		}
		run("", nil, herdrBin, "workspace", "focus", ws)
		return ws, pane, nil
	}

	var created struct {
		Result struct {
			Workspace struct {
				WorkspaceID string `json:"workspace_id"`
			} `json:"workspace"`
			Tab struct {
				TabID string `json:"tab_id"`
			} `json:"tab"`
			RootPane struct {
				PaneID string `json:"pane_id"`
			} `json:"root_pane"`
		} `json:"result"`
	}
	if err := herdrJSON(&created, "workspace", "create", "--cwd", dir, "--label", treeLabel(dir), "--focus"); err != nil {
		return "", "", err
	}
	ws, root := created.Result.Workspace.WorkspaceID, created.Result.RootPane.PaneID
	tagWorkspace(ws, dir)
	if pane != "" {
		return ws, movePane(pane, created.Result.Tab.TabID, root), nil
	}
	var split struct {
		Result struct {
			Pane paneInfo `json:"pane"`
		} `json:"result"`
	}
	if err := herdrJSON(&split, "pane", "split", root, "--direction", "right", "--ratio", ratio,
		"--cwd", rightCwdFor(dir), "--no-focus"); err != nil {
		return ws, "", err
	}
	if rightCmd != "" {
		run("", nil, herdrBin, "pane", "run", split.Result.Pane.PaneID, rightCmd)
	}
	return ws, "", nil
}

// movePane 은 pane 을 target 오른쪽으로 옮기고 포커스를 준다. target 이 왼쪽 비율을 갖는다.
func movePane(pane, tab, target string) string {
	var resp struct {
		Result struct {
			MoveResult struct {
				Pane paneInfo `json:"pane"`
			} `json:"move_result"`
		} `json:"result"`
	}
	herdrJSON(&resp, "pane", "move", pane, "--tab", tab, "--split", "right", "--target-pane", target,
		"--ratio", ratio, "--focus")
	return resp.Result.MoveResult.Pane.PaneID
}

// hereCheck 는 --here 로 바꿔도 되는지 보고 실제 패널 ID 를 돌려준다.
// tree 를 만들기 전에도 불러서, 거절할 경우 아무것도 만들지 않는다.
func hereCheck(dir, pane string) (string, error) {
	dir = strings.TrimSuffix(dir, "/")
	real := paneID(pane)
	if real == "" {
		return "", fmt.Errorf("패널 없음 · %s", pane)
	}
	ws := wsOf(real)
	wsLoad()
	id := ""
	if hasTracker(dir) {
		id = treeID(dir)
	}
	if tag, _ := wsTag(ws); validID(tag) && tag != id {
		return "", fmt.Errorf("다른 tree 의 워크스페이스 · %s (%s)", workspaceLabel(ws), ws)
	}
	if hasTracker(dir) {
		if other, how, ok := workspaceFor(dir); ok && how == "tag" && other != ws {
			return "", fmt.Errorf("이 tree 의 워크스페이스가 이미 있음 · %s (%s)", workspaceLabel(other), other)
		}
	}
	return real, nil
}

// attachHere 는 pane 이 있는 워크스페이스를 tree 워크스페이스로 바꾼다. 토큰을 붙이고 이름을 태그로
// 바꾸며, 패널이 그 하나뿐이면 왼쪽에 이슈 폴더 셸을 둔다.
func attachHere(dir, pane string) (string, string, error) {
	dir = strings.TrimSuffix(dir, "/")
	real, err := hereCheck(dir, pane)
	if err != nil {
		return "", "", err
	}
	ws := wsOf(real)
	tagWorkspace(ws, dir)
	run("", nil, herdrBin, "workspace", "rename", ws, treeLabel(dir))
	if len(paneList(ws)) == 1 {
		// split 은 오른쪽에만 새 패널을 만들어서, 만든 뒤 자리를 바꿔 이슈 폴더 셸을 왼쪽에 둔다.
		var split struct {
			Result struct {
				Pane paneInfo `json:"pane"`
			} `json:"result"`
		}
		if herdrJSON(&split, "pane", "split", real, "--direction", "right", "--ratio", ratio, "--cwd", dir, "--no-focus") == nil {
			run("", nil, herdrBin, "pane", "swap", "--source-pane", split.Result.Pane.PaneID, "--target-pane", real)
		}
	}
	return ws, real, nil
}

func openPluginPane(entry string) int {
	_, _, code := run("", nil, herdrBin, "plugin", "pane", "open", "--plugin", pluginID, "--entrypoint", entry, "--focus")
	return code
}
