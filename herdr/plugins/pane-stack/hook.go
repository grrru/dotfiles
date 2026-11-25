package main

import (
	"encoding/json"
	"os"
)

// cmdHook handles a herdr pane event. Herdr runs it for pane events everywhere, so it
// leaves at once unless the event touches a pane or workspace in the state file.
func cmdHook() {
	st, ok := readState()
	if !ok {
		return
	}
	var ev struct {
		Data struct {
			PaneID      string `json:"pane_id"`
			WorkspaceID string `json:"workspace_id"`
			Pane        struct {
				PaneID      string `json:"pane_id"`
				WorkspaceID string `json:"workspace_id"`
			} `json:"pane"`
		} `json:"data"`
	}
	json.Unmarshal([]byte(os.Getenv("HERDR_PLUGIN_EVENT_JSON")), &ev)
	pane, ws := ev.Data.PaneID, ev.Data.WorkspaceID
	if pane == "" {
		pane = ev.Data.Pane.PaneID
	}
	if ws == "" {
		ws = ev.Data.Pane.WorkspaceID
	}
	switch os.Getenv("HERDR_PLUGIN_EVENT") {
	case "pane.exited", "pane.closed":
		if pane != "" && st.mentions(pane) {
			lock()
			defer unlock()
			// Read again under the lock: the plugin's own close fires this while it runs.
			st, _ = readState()
			if slot := st.slotShowing(pane); slot != nil {
				refill(st, *slot, pane)
			}
			if m := st.member(pane); m != nil {
				retitle(ws, m.Stack)
			}
			settle()
			return
		}
	case "pane.created", "pane.moved":
	default:
		return
	}
	// Any other change to a workspace with a slot may reshape the slot's surroundings. A
	// burst of moves (a layout preset) fires many hooks at once: each marks the state dirty
	// and only the one holding the lock saves, again until no hook marked it meanwhile.
	if ws == "" || !st.hasSlotIn(ws) {
		return
	}
	os.MkdirAll(stateDir, 0o755)
	if f, err := os.Create(dirtyFile); err == nil {
		f.Close()
	}
	if !takeLock() {
		return
	}
	defer unlock()
	settle()
}

// settle saves until no hook marked the state dirty during the last save.
func settle() {
	for i := 0; i < 20; i++ {
		os.Remove(dirtyFile)
		save()
		if !exists(dirtyFile) {
			return
		}
	}
}

// cmdRestore re-tags the panes the state file names after a server restart, which brings
// back pane ids but not their tokens, unless tokens are already present.
func cmdRestore() {
	st, ok := readState()
	if !ok {
		return
	}
	panes := paneList("")
	live := map[string]bool{}
	for _, p := range panes {
		if p.stack() != "" {
			return
		}
		live[p.PaneID] = true
	}
	type key struct{ ws, stack string }
	seen := map[key]bool{}
	var stacks []key
	for _, m := range st.Members {
		if !live[m.PaneID] {
			continue
		}
		if tag(m.PaneID, m.Stack, m.Order.int()) != nil {
			continue
		}
		for _, p := range panes {
			if p.PaneID == m.PaneID {
				k := key{p.WorkspaceID, m.Stack}
				if !seen[k] {
					seen[k] = true
					stacks = append(stacks, k)
				}
			}
		}
	}
	for _, k := range stacks {
		retitle(k.ws, k.stack)
	}
}
