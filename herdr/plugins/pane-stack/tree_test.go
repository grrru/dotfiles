package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// lcm is L | (C / M) on a 120x40 screen: L takes 0.6 of the width, C 0.3 of the right.
func lcm() Layout {
	return Layout{
		TabID: "w1:t1", WorkspaceID: "w1",
		Panes: []LayoutPane{
			{"w1:p1", Rect{0, 0, 72, 40}},
			{"w1:p2", Rect{72, 0, 48, 12}},
			{"w1:p3", Rect{72, 12, 48, 28}},
		},
		Splits: []Split{
			{"split_0_root", Rect{0, 0, 120, 40}, "right", 0.6},
			{"split_1_1", Rect{72, 0, 48, 40}, "down", 0.3},
		},
	}
}

func TestTree(t *testing.T) {
	ns := nodesOf(lcm())
	var root node
	for _, n := range ns {
		if n.id == "split_0_root" {
			root = n
		}
	}
	got := treeOf(root, ns)
	want := &Tree{Direction: "right", Ratio: 0.6,
		First:  &Tree{Pane: "w1:p1"},
		Second: &Tree{Direction: "down", Ratio: 0.3, First: &Tree{Pane: "w1:p2"}, Second: &Tree{Pane: "w1:p3"}}}
	if !reflect.DeepEqual(got, want) {
		a, _ := json.Marshal(got)
		t.Fatalf("tree = %s", a)
	}
	if l := got.leaves(); !reflect.DeepEqual(l, []string{"w1:p1", "w1:p2", "w1:p3"}) {
		t.Fatalf("leaves = %v", l)
	}
	if p := parentOf(ns[2], ns); p == nil || p.id != "split_1_1" {
		t.Fatalf("parent of p3 = %v", p)
	}
	if p := parentOf(root, ns); p != nil {
		t.Fatalf("root has parent %v", p)
	}
}

func TestPlanFor(t *testing.T) {
	// The slot was M (second child of the down split); after M went, C fills the split.
	after := Layout{Panes: []LayoutPane{{"w1:p1", Rect{0, 0, 72, 40}}, {"w1:p2", Rect{72, 0, 48, 40}}},
		Splits: []Split{{"split_0_root", Rect{0, 0, 120, 40}, "right", 0.6}}}
	r := Rect{72, 0, 48, 40}
	slot := Slot{Direction: "down", Ratio: 0.3, Rect: &r, Sibling: []string{"w1:p2"}}
	if p := planFor(after, slot); p == nil || p.Pane != "w1:p2" {
		t.Fatalf("plan by rectangle = %+v", p)
	}
	// Reshaped since: the rectangle is gone but the sibling panes are still found by name.
	moved := Rect{0, 0, 1, 1}
	slot.Rect = &moved
	if p := planFor(after, slot); p == nil || p.Pane != "w1:p2" {
		t.Fatalf("plan by name = %+v", p)
	}
	slot.Sibling = []string{"w1:p9"}
	if p := planFor(after, slot); p != nil {
		t.Fatalf("plan for vanished siblings = %+v", p)
	}
}

func TestReadState(t *testing.T) {
	stackFile = filepath.Join(t.TempDir(), "stacks.json")
	os.WriteFile(stackFile, []byte(`{"members":[{"pane_id":"w1:p1","workspace":"w1","stack":"g","order":"3"}],
		"slots":[{"stack":"g","shown":"w1:p1","tab":"w1:t1","workspace":"w1","alone":false,"direction":"right",
		"ratio":0.5,"rect":{"height":40,"width":120,"x":0,"y":0},"first":true,"sibling":["w1:p2"]}]}`), 0o644)
	st, ok := readState()
	if !ok || st.Members[0].Order.int() != 3 || st.Members[0].Stack != "g" || !st.Slots[0].First || st.Slots[0].Rect.Width != 120 {
		t.Fatalf("state = %+v", st)
	}
	if !st.mentions("w1:p2") || st.mentions("w1:p3") || !st.hasSlotIn("w1") {
		t.Fatal("lookups")
	}
}

// An unreachable herdr must leave the state file alone: restore and the hooks save.
func TestSaveKeepsStateWhenHerdrFails(t *testing.T) {
	stateDir = t.TempDir()
	stackFile = filepath.Join(stateDir, "stacks.json")
	herdrBin = "/bin/false"
	before := `{"members":[{"pane_id":"w1:p1","workspace":"w1","stack":"g","order":"1"}],` +
		`"slots":[{"stack":"g","shown":"w1:p1","tab":"w1:t1","workspace":"w1","alone":true}]}`
	os.WriteFile(stackFile, []byte(before), 0o644)
	cmdRestore()
	save()
	if got, _ := os.ReadFile(stackFile); string(got) != before {
		t.Fatalf("the state file was rewritten: %s", got)
	}
}

func TestFitScreen(t *testing.T) {
	red, reset := "\x1b[31m", "\x1b[0m"
	// A dashboard centered in a terminal much wider and taller than a 30x6 preview.
	screen := "\r\n\r\n\r\n" + strings.Repeat(" ", 60) + red + "== DASH ==" + reset + "     \r\n" +
		"\x1b[0m" + strings.Repeat(" ", 59) + "Find File f\r\n" + strings.Repeat(" ", 59) + "Quit      q\r\n\r\n\r\n"
	want := "\n" + "          " + red + "== DASH ==" + reset + "\n" + "         \x1b[0mFind File f\n" + "         Quit      q"
	if got := fitScreen(screen, 6, 30); got != want {
		t.Fatalf("dashboard = %q", got)
	}
	// nvim marks the rows past its dashboard buffer with "~" at the left edge.
	vim := "\n\n" + strings.Repeat(" ", 60) + "Find File f" + strings.Repeat(" ", 50) + "\x1b[0m\n" + strings.Repeat(" ", 60) + "Quit      q\n" +
		"\x1b[34m~\x1b[0m\n~\n~\n"
	if got := fitScreen(vim, 4, 30); got != "\n         Find File f"+strings.Repeat(" ", 50)+"\x1b[0m\n         Quit      q" {
		t.Fatalf("vim = %q", got)
	}
	// A shell keeps its place and its last rows.
	shell := "$ ls\na  b\n$ echo hi\nhi\n$ \n\n"
	if got := fitScreen(shell, 3, 30); got != "$ echo hi\nhi\n$" {
		t.Fatalf("shell = %q", got)
	}
	if shownWidth("가나 ab") != 7 {
		t.Fatal("wide characters")
	}
}
