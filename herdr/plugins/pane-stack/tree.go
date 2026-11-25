package main

import (
	"sort"
)

// The split tree of a `pane layout` result, rebuilt from rectangles: a node's parent is
// the smallest split whose rectangle contains it, and a split's first child is the left or
// upper one.

type node struct {
	id        string
	split     bool
	rect      Rect
	direction string
	ratio     float64
}

type Tree struct {
	Pane      string  `json:"pane,omitempty"`
	Direction string  `json:"direction,omitempty"`
	Ratio     float64 `json:"ratio,omitempty"`
	First     *Tree   `json:"first,omitempty"`
	Second    *Tree   `json:"second,omitempty"`
}

func nodesOf(l Layout) []node {
	ns := make([]node, 0, len(l.Panes)+len(l.Splits))
	for _, p := range l.Panes {
		ns = append(ns, node{id: p.PaneID, rect: p.Rect})
	}
	for _, s := range l.Splits {
		ns = append(ns, node{id: s.ID, split: true, rect: s.Rect, direction: s.Direction, ratio: s.Ratio})
	}
	return ns
}

func inside(a, b Rect) bool {
	return a.X >= b.X && a.Y >= b.Y && a.X+a.Width <= b.X+b.Width && a.Y+a.Height <= b.Y+b.Height
}

func area(r Rect) int { return r.Width * r.Height }

// parentOf is the smallest split holding n, the first of equals; nil for the root.
func parentOf(n node, ns []node) *node {
	var best *node
	for i := range ns {
		s := &ns[i]
		if !s.split || s.id == n.id || !inside(n.rect, s.rect) {
			continue
		}
		if best == nil || area(s.rect) < area(best.rect) {
			best = s
		}
	}
	return best
}

// kidsOf is a split's children, the left or upper one first.
func kidsOf(s node, ns []node) []node {
	var kids []node
	for _, n := range ns {
		if n.id == s.id {
			continue
		}
		if p := parentOf(n, ns); p != nil && p.id == s.id {
			kids = append(kids, n)
		}
	}
	sort.SliceStable(kids, func(i, j int) bool {
		if s.direction == "right" {
			return kids[i].rect.X < kids[j].rect.X
		}
		return kids[i].rect.Y < kids[j].rect.Y
	})
	return kids
}

// treeOf is the subtree under n, or nil when the rectangles do not form one.
func treeOf(n node, ns []node) *Tree {
	if !n.split {
		return &Tree{Pane: n.id}
	}
	k := kidsOf(n, ns)
	if len(k) != 2 {
		return nil
	}
	first, second := treeOf(k[0], ns), treeOf(k[1], ns)
	if first == nil || second == nil {
		return nil
	}
	return &Tree{Direction: n.direction, Ratio: n.ratio, First: first, Second: second}
}

func (t *Tree) leaves() []string {
	if t.Pane != "" {
		return []string{t.Pane}
	}
	return append(t.First.leaves(), t.Second.leaves()...)
}
