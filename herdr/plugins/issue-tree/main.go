// issue-tree 는 이슈 tree(이슈 폴더와 그 안의 레포별 worktree)를 herdr popup 에서 고르고, 만들고, 정리한다.
//
//	issue-tree pick            이슈 tree 목록 popup 을 띄운다 (action)
//	issue-tree new             새 이슈 tree popup 을 띄운다 (action)
//	issue-tree picker          목록 popup 본체. ↵ 열기 · ^O 새 tree · ^R 레포 추가 · ^X 정리
//	issue-tree creator         새 이슈 tree popup 본체
//	issue-tree open <dir>      이슈 tree 를 연다
//	issue-tree setup <issue> [--tag <tag>] [--repo <repo>]... [--here <pane_id> | --pane <pane_id> | --no-open]
//	                           대화 없이 tree 를 만들거나(같은 태그의 tree 가 있으면 레포를 더한다) 연다.
//	                           새 tree 는 --repo 가 하나 이상 있어야 한다.
//	                           --here 는 그 패널이 있는 워크스페이스를 tree 워크스페이스로 바꾼다.
//	                           --pane 은 새 tree 워크스페이스를 만들고 그 패널을 오른쪽으로 옮긴다.
//	                           에이전트는 대화 중인 패널을 "$HERDR_PANE_ID" 로 넘긴다.
//	issue-tree restore-tags    서버 시작 때 워크스페이스 토큰을 다시 붙인다 (startup hook)
//	issue-tree sync-tags       워크스페이스 토큰 목록을 state 파일에 맞춘다 (workspace.closed hook)
//
// 그 밖의 하위 명령(preview, form-*, repo-*, clean-plan)은 fzf 가 부르는 콜백이다.
//
// 설정은 환경 변수와 "$(herdr plugin config-dir dotfiles.issue-tree)/config.sh" 의 KEY=VALUE 줄로 정한다.
//
//	ISSUE_TREE_RIGHT_CMD   오른쪽 패널에서 실행할 명령. 빈 값이면 셸만 연다 (기본 "claude agents")
//	ISSUE_TREE_RIGHT_CWD   오른쪽 패널 cwd. main(첫 레포 main 체크아웃) | worktree(첫 레포 worktree) | issue
//	ISSUE_TREE_RATIO       왼쪽 패널 너비 비율 (기본 0.65)
//	WORKTREE, WORKSPACE    이슈 tree 폴더와 레포 폴더. herdr 서버 환경에 없을 때만 지정한다.
//
// 필요: git, fzf 0.58+
package main

import (
	"fmt"
	"os"
	"runtime/debug"
)

const usage = `issue-tree pick | new | picker | creator | open <dir>
issue-tree setup <issue> [--tag <tag>] [--repo <repo>]... [--here <pane_id> | --pane <pane_id> | --no-open]
issue-tree restore-tags | sync-tags
`

func main() {
	loadConfig()
	os.Exit(dispatch(os.Args[1:]))
}

func arg(args []string, i int) string {
	if i < len(args) {
		return args[i]
	}
	return ""
}

func need(args []string, n int) bool {
	if len(args) < n {
		fmt.Fprint(os.Stderr, usage)
		return false
	}
	return true
}

func dispatch(args []string) int {
	switch arg(args, 0) {
	case "pick":
		return openPluginPane("picker")
	case "new":
		return openPluginPane("creator")
	case "picker":
		return popup(cmdPicker)
	case "creator":
		return popup(cmdCreator)
	case "open":
		if !need(args, 2) {
			return 2
		}
		if _, _, err := openTree(args[1], ""); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		return 0
	case "setup":
		return cmdSetupCLI(args[1:])
	case "restore-tags":
		return cmdRestoreTags()
	case "sync-tags":
		saveTags()
		return 0
	case "preview":
		if !need(args, 2) {
			return 2
		}
		return cmdPreview(args[1])
	case "form-items":
		if !need(args, 2) {
			return 2
		}
		return cmdFormItems(args[1])
	case "form-event":
		if !need(args, 3) {
			return 2
		}
		return cmdFormEvent(args[1], args[2], arg(args, 3), arg(args, 4))
	case "form-preview":
		if !need(args, 2) {
			return 2
		}
		return cmdFormPreview(args[1], arg(args, 2), arg(args, 3))
	case "form-repos":
		if !need(args, 2) {
			return 2
		}
		return cmdFormRepos(args[1])
	case "repo-key":
		if !need(args, 3) {
			return 2
		}
		return cmdRepoKey(args[1], args[2])
	case "repo-preview":
		if !need(args, 2) {
			return 2
		}
		return cmdRepoPreview(args[1])
	case "clean-plan":
		if !need(args, 2) {
			return 2
		}
		return cmdCleanPlan(args[1], arg(args, 2))
	default:
		fmt.Fprint(os.Stderr, usage)
		return 2
	}
}

// popup 은 popup 본체를 실행한다. 예상 못 한 오류로 끝나면 화면이 말없이 닫히지 않게 멈춰서 보여 준다.
func popup(body func() int) (rc int) {
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("\n%s issue-tree 오류 · %v\n%s", FAIL, r, debug.Stack())
			pause("")
			rc = 1
		}
	}()
	rc = body()
	if rc != 0 {
		fmt.Printf("\n%s issue-tree 오류 (exit %d)\n", FAIL, rc)
		pause("")
	}
	return rc
}
