package main

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

var safeShellWord = regexp.MustCompile(`^[A-Za-z0-9_./:@%+=,-]+$`)

// shellQuote 는 fzf 가 bash -c 로 실행하는 명령에 넣을 인자를 감싼다.
func shellQuote(s string) string {
	if s != "" && safeShellWord.MatchString(s) {
		return s
	}
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

func tilde(path string) string {
	if homeDir != "" && strings.HasPrefix(path, homeDir+"/") {
		return "~" + strings.TrimPrefix(path, homeDir)
	}
	return path
}

// ago 는 unix 초를 "3일 전" 으로 쓴다.
func ago(ts int64) string {
	d := time.Now().Unix() - ts
	switch {
	case d < 60:
		return "방금"
	case d < 3600:
		return fmt.Sprintf("%d분 전", d/60)
	case d < 86400:
		return fmt.Sprintf("%d시간 전", d/3600)
	case d < 86400*30:
		return fmt.Sprintf("%d일 전", d/86400)
	default:
		return fmt.Sprintf("%d개월 전", d/86400/30)
	}
}

// joinSome 은 "a · b · c 외 N" 으로 앞의 max 개만 쓴다.
func joinSome(max int, items []string) string {
	out := ""
	for i, item := range items {
		if i >= max {
			break
		}
		if out != "" {
			out += " · "
		}
		out += item
	}
	if len(items) > max {
		out += fmt.Sprintf(" 외 %d", len(items)-max)
	}
	return out
}

func base(path string) string {
	if i := strings.LastIndex(path, "/"); i >= 0 {
		return path[i+1:]
	}
	return path
}

func namesOf(paths []string) string {
	parts := make([]string, len(paths))
	for i, p := range paths {
		parts[i] = base(p)
	}
	return strings.Join(parts, " · ")
}

func pad(s string, w int) string {
	return fmt.Sprintf("%-*s", w, s)
}

// run 은 명령을 실행해 stdout, stderr, 종료 코드를 돌려준다. stdout 끝의 줄바꿈은 지운다.
func run(dir string, env []string, name string, args ...string) (string, string, int) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	if env != nil {
		cmd.Env = append(os.Environ(), env...)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	code := 0
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			code = exitErr.ExitCode()
		} else {
			code = 127
		}
	}
	return strings.TrimRight(stdout.String(), "\n"), stderr.String(), code
}

// git 은 git -C dir 를 실행한다.
func git(dir string, args ...string) (string, int) {
	out, _, code := run("", nil, "git", append([]string{"-C", dir}, args...)...)
	return out, code
}

func gitErr(dir string, args ...string) (string, string, int) {
	return run("", nil, "git", append([]string{"-C", dir}, args...)...)
}

// gitNet 은 원격에 붙는 git 이다. 레포에 core.sshCommand 가 있으면 GIT_SSH_COMMAND 로 덮지 않는다.
func gitNet(dir string, args ...string) (string, string, int) {
	if v, _ := git(dir, "config", "--get", "core.sshCommand"); v != "" {
		cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
		var env []string
		for _, kv := range os.Environ() {
			if !strings.HasPrefix(kv, "GIT_SSH_COMMAND=") {
				env = append(env, kv)
			}
		}
		cmd.Env = env
		var stdout, stderr bytes.Buffer
		cmd.Stdout, cmd.Stderr = &stdout, &stderr
		err := cmd.Run()
		code := 0
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			code = exitErr.ExitCode()
		} else if err != nil {
			code = 127
		}
		return strings.TrimRight(stdout.String(), "\n"), stderr.String(), code
	}
	return gitErr(dir, args...)
}

var errLine = regexp.MustCompile(`(?i)^(fatal|error):`)

// errMsg 는 git 오류 출력에서 보여 줄 한 줄을 고른다 (fatal:/error: 줄, 없으면 마지막 줄).
func errMsg(text string) string {
	last := ""
	for _, line := range strings.Split(text, "\n") {
		if errLine.MatchString(line) {
			return line
		}
		if strings.TrimSpace(line) != "" {
			last = line
		}
	}
	return last
}

func lines(s string) []string {
	if s == "" {
		return nil
	}
	return strings.Split(s, "\n")
}

func exists(path string) bool {
	_, err := os.Lstat(path)
	return err == nil
}

func isFile(path string) bool {
	fi, err := os.Stat(path)
	return err == nil && fi.Mode().IsRegular()
}

func isDir(path string) bool {
	fi, err := os.Stat(path)
	return err == nil && fi.IsDir()
}

// writeAtomic 은 같은 폴더의 임시 파일에 쓴 뒤 이름을 바꾼다.
func writeAtomic(path, content string) error {
	dir := path[:strings.LastIndex(path, "/")]
	f, err := os.CreateTemp(dir, "."+base(path)+".")
	if err != nil {
		return err
	}
	if _, err := f.WriteString(content); err != nil {
		f.Close()
		os.Remove(f.Name())
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(f.Name())
		return err
	}
	return os.Rename(f.Name(), path)
}
