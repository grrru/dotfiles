package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

// Member and Slot are the state file's records. Orders are kept as the token strings.
type Member struct {
	PaneID    string    `json:"pane_id"`
	Workspace string    `json:"workspace"`
	Stack     string    `json:"stack"`
	Order     flexOrder `json:"order"`
}

// A slot is where a stack's single shown terminal sits: alone in its tab, or one side of
// a split whose other side holds the sibling panes.
type Slot struct {
	Stack     string   `json:"stack"`
	Shown     string   `json:"shown"`
	Tab       string   `json:"tab"`
	Workspace string   `json:"workspace"`
	Alone     bool     `json:"alone"`
	Direction string   `json:"direction,omitempty"`
	Ratio     float64  `json:"ratio,omitempty"`
	Rect      *Rect    `json:"rect,omitempty"`
	First     bool     `json:"first,omitempty"`
	Sibling   []string `json:"sibling,omitempty"`
}

type State struct {
	Members []Member `json:"members"`
	Slots   []Slot   `json:"slots"`
}

// flexOrder reads an order written as a string or a number.
type flexOrder string

func (o *flexOrder) UnmarshalJSON(b []byte) error {
	var s string
	if json.Unmarshal(b, &s) == nil {
		*o = flexOrder(s)
		return nil
	}
	var n json.Number
	if err := json.Unmarshal(b, &n); err != nil {
		*o = ""
		return nil
	}
	*o = flexOrder(n.String())
	return nil
}

func (o flexOrder) int() int {
	n, _ := strconv.Atoi(string(o))
	return n
}

func readState() (State, bool) {
	data, err := os.ReadFile(stackFile)
	if err != nil {
		return State{}, false
	}
	var st State
	json.Unmarshal(data, &st)
	return st, true
}

// mentions tells whether the state file names a pane anywhere.
func (st State) mentions(pane string) bool {
	for _, m := range st.Members {
		if m.PaneID == pane {
			return true
		}
	}
	for _, s := range st.Slots {
		if s.Shown == pane {
			return true
		}
		for _, p := range s.Sibling {
			if p == pane {
				return true
			}
		}
	}
	return false
}

func (st State) slotShowing(pane string) *Slot {
	for i := range st.Slots {
		if st.Slots[i].Shown == pane {
			return &st.Slots[i]
		}
	}
	return nil
}

func (st State) member(pane string) *Member {
	for i := range st.Members {
		if st.Members[i].PaneID == pane {
			return &st.Members[i]
		}
	}
	return nil
}

func (st State) hasSlotIn(ws string) bool {
	for _, s := range st.Slots {
		if s.Workspace == ws {
			return true
		}
	}
	return false
}

func writeState(st State) error {
	if st.Members == nil {
		st.Members = []Member{}
	}
	if st.Slots == nil {
		st.Slots = []Slot{}
	}
	data, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return err
	}
	f, err := os.CreateTemp(stateDir, filepath.Base(stackFile)+".")
	if err != nil {
		return err
	}
	if _, err := f.Write(append(data, '\n')); err != nil {
		f.Close()
		os.Remove(f.Name())
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(f.Name())
		return err
	}
	return os.Rename(f.Name(), stackFile)
}

var locked bool

// takeLock makes one attempt at the lock; a lock older than a minute belongs to a run
// that died. A directory is the lock because macOS has no flock, and it is the same one
// every version of this plugin uses.
func takeLock() bool {
	os.MkdirAll(stateDir, 0o755)
	if os.Mkdir(lockDir, 0o755) == nil {
		locked = true
		return true
	}
	if fi, err := os.Stat(lockDir); err == nil && time.Since(fi.ModTime()) > time.Minute {
		os.Remove(lockDir)
	}
	return false
}

// lock waits up to five seconds, since overlapping runs would interleave their moves.
func lock() {
	for i := 0; i < 50; i++ {
		if takeLock() {
			return
		}
		time.Sleep(100 * time.Millisecond)
	}
	fail("다른 pane-stack 동작이 진행 중입니다", "잠시 뒤 다시 누르세요")
}

func unlock() {
	if locked {
		os.Remove(lockDir)
		locked = false
	}
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
