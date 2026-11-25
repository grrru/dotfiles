package main

import (
	"fmt"
	"sort"
	"strings"
	"unicode/utf8"
)

// ctx is the pane an action runs on and its slot.
type ctx struct {
	F, W, Tab, Stack, Cwd, TermID string
}

// load names the current pane, refusing zoomed tabs (herdr refuses the moves). A parked
// pane stands for its stack's shown terminal: a key pressed again while the previous
// switch runs still names the pane that switch parks. With no single shown terminal there
// is no slot to fill, so it is refused.
func load(id string) *ctx {
	p, err := paneGet(id)
	if err != nil {
		fail("pane "+id+" 을 찾지 못했습니다", "")
	}
	c := &ctx{F: id, W: p.WorkspaceID, Tab: p.TabID, Stack: p.stack(), Cwd: p.dir(), TermID: p.TerminalID}
	if park := parkTab(c.W); park != "" && c.Tab == park {
		var shown []string
		if c.Stack != "" {
			for _, m := range stackPanes(c.W, c.Stack) {
				if m.TabID != park {
					shown = append(shown, m.PaneID)
				}
			}
		}
		if len(shown) != 1 {
			fail("보관 탭 안에서는 동작하지 않습니다", "스택이 보이는 pane 에서 다시 누르세요")
		}
		return load(shown[0])
	}
	if l, err := layoutOf(c.F); err == nil && l.Zoomed {
		fail("zoom 상태에서는 동작하지 않습니다", "zoom 을 풀고 다시 누르세요")
	}
	return c
}

func (c *ctx) members() []Pane { return stackPanes(c.W, c.Stack) }

// besideLargest moves a pane into a tab, splitting its largest pane along the long side
// (a cell is about twice as tall as wide) so panes keep a usable size there.
func besideLargest(ws, pane, tab, focus string) error {
	l, err := layoutOf(firstPaneIn(ws, tab))
	if err != nil {
		return err
	}
	if len(l.Panes) == 0 {
		return fmt.Errorf("tab %s has no panes", tab)
	}
	big := l.Panes[0]
	for _, p := range l.Panes[1:] {
		if area(p.Rect) >= area(big.Rect) {
			big = p
		}
	}
	dir := "down"
	if big.Rect.Width >= 2*big.Rect.Height {
		dir = "right"
	}
	_, err = tryMove(pane, "--tab", tab, "--split", dir, "--target-pane", big.PaneID, focus)
	return err
}

// park sends a pane to the parking tab, opening it when it is gone.
func park(ws, pane string) error {
	p := parkTab(ws)
	if p == "" {
		_, err := tryMove(pane, "--new-tab", "--workspace", ws, "--label", parkLabel, "--no-focus")
		return err
	}
	return besideLargest(ws, pane, p, "--no-focus")
}

// bring moves a stack member into the current slot and parks the current pane.
func (c *ctx) bring(t string) {
	if _, err := tryMove(t, "--tab", c.Tab, "--split", "down", "--target-pane", c.F, "--focus"); err != nil {
		fail("터미널을 바꾸지 못했습니다", err.Error())
	}
	if err := park(c.W, c.F); err != nil {
		fail("지금 터미널을 보관하지 못했습니다", err.Error()+" (두 터미널이 나란히 보입니다)")
	}
}

// retitle numbers the stack's terminals on their borders, or dissolves a stack that is
// down to one terminal.
func retitle(ws, stack string) {
	ms := stackPanes(ws, stack)
	n := len(ms)
	if n <= 1 {
		if n == 1 {
			untag(ms[0].PaneID)
		}
		return
	}
	names := make([]string, n)
	for i, m := range ms {
		names[i] = nameOf(m)
	}
	for i, m := range ms {
		var b strings.Builder
		b.WriteString("⧉")
		for j, name := range names {
			if j == i {
				fmt.Fprintf(&b, " [%d:%s]", j+1, name)
			} else {
				fmt.Fprintf(&b, " %d:%s", j+1, name)
			}
		}
		title := b.String()
		if utf8.RuneCountInString(title) > titleMax {
			title = fmt.Sprintf("⧉ %d/%d %s", i+1, n, names[i])
		}
		setTitle(m.PaneID, title)
	}
}

func (c *ctx) cmdNew() {
	if c.Stack == "" {
		c.Stack = c.TermID
		if err := tag(c.F, c.Stack, 1); err != nil {
			fail("스택에 터미널을 더하지 못했습니다", err.Error())
		}
	}
	last := 0
	for _, m := range c.members() {
		last = max(last, m.order())
	}
	args := []string{"pane", "split", c.F, "--direction", "down"}
	if c.Cwd != "" {
		args = append(args, "--cwd", c.Cwd)
	}
	var r struct {
		Result struct {
			Pane Pane `json:"pane"`
		} `json:"result"`
	}
	if herdrJSON(&r, append(args, "--focus")...) != nil || r.Result.Pane.PaneID == "" {
		fail("새 터미널을 열지 못했습니다", "")
	}
	n := r.Result.Pane.PaneID
	if err := tag(n, c.Stack, last+1); err != nil {
		fail("스택에 터미널을 더하지 못했습니다", err.Error())
	}
	if err := park(c.W, c.F); err != nil {
		fail("지금 터미널을 보관하지 못했습니다", err.Error()+" (두 터미널이 나란히 보입니다)")
	}
	retitle(c.W, c.Stack)
}

// neighbor is the stack member step places after the current pane, cyclically.
func (c *ctx) neighbor(step int) string {
	ms := c.members()
	n := len(ms)
	if n <= 1 {
		return ""
	}
	me := 0
	for i, m := range ms {
		if m.PaneID == c.F {
			me = i
		}
	}
	return ms[((me+step%n)%n+n)%n].PaneID
}

func (c *ctx) cmdSwitch(step int) {
	if c.Stack == "" {
		fail("No stacks", "")
	}
	t := c.neighbor(step)
	if t == "" {
		notify("스택에 다른 터미널이 없습니다", "")
		return
	}
	c.bring(t)
	retitle(c.W, c.Stack)
}

func (c *ctx) isMember(pane string) bool {
	for _, m := range c.members() {
		if m.PaneID == pane {
			return true
		}
	}
	return false
}

func (c *ctx) cmdGoto(t string) {
	if c.Stack == "" {
		fail("No stacks", "")
	}
	if t == c.F {
		return
	}
	if !c.isMember(t) {
		fail("스택에서 그 터미널을 찾지 못했습니다", t)
	}
	c.bring(t)
	retitle(c.W, c.Stack)
}

func (c *ctx) cmdClose() {
	if c.Stack == "" {
		fail("No stacks", "")
	}
	t := c.neighbor(1)
	if t == "" {
		fail("스택에 다른 터미널이 없습니다", "마지막 터미널은 C-a x 로 닫으세요")
	}
	if _, err := tryMove(t, "--tab", c.Tab, "--split", "down", "--target-pane", c.F, "--focus"); err != nil {
		fail("터미널을 닫지 못했습니다", err.Error())
	}
	herdr("pane", "close", c.F)
	retitle(c.W, c.Stack)
}

// cmdDrop closes one terminal of the stack: the shown one as close does, a parked one in
// place.
func (c *ctx) cmdDrop(t string) {
	if t == c.F {
		c.cmdClose()
		return
	}
	if c.Stack == "" || !c.isMember(t) {
		fail("스택에서 그 터미널을 찾지 못했습니다", t)
	}
	if _, err := herdr("pane", "close", t); err != nil {
		fail("터미널을 닫지 못했습니다", err.Error())
	}
	retitle(c.W, c.Stack)
}

// save writes every stack's members, and where each stack's shown terminal sits, to the
// state file. It writes nothing when herdr does not answer, since an empty answer would
// erase the stacks the file keeps for a restart.
func save() {
	panes, err := listPanes("")
	if err != nil {
		return
	}
	tabs, err := listTabs("")
	if err != nil {
		return
	}
	parked := map[string]bool{}
	for _, t := range tabs {
		if t.Label == parkLabel {
			parked[t.TabID] = true
		}
	}
	shown := map[string][]string{}
	var stacks []string
	st := State{Members: []Member{}, Slots: []Slot{}}
	for _, p := range panes {
		g := p.stack()
		if g == "" {
			continue
		}
		st.Members = append(st.Members, Member{PaneID: p.PaneID, Workspace: p.WorkspaceID, Stack: g, Order: flexOrder(p.Tokens["ps_order"])})
		if parked[p.TabID] {
			continue
		}
		if _, ok := shown[g]; !ok {
			stacks = append(stacks, g)
		}
		shown[g] = append(shown[g], p.PaneID)
	}
	sort.Strings(stacks)
	for _, g := range stacks {
		if len(shown[g]) != 1 {
			continue
		}
		if s, ok := slotOf(g, shown[g][0]); ok {
			st.Slots = append(st.Slots, s)
		}
	}
	writeState(st)
}

func slotOf(stack, pane string) (Slot, bool) {
	l, err := layoutOf(pane)
	if err != nil {
		return Slot{}, false
	}
	s := Slot{Stack: stack, Shown: pane, Tab: l.TabID, Workspace: l.WorkspaceID}
	ns := nodesOf(l)
	var me *node
	for i := range ns {
		if ns[i].id == pane {
			me = &ns[i]
		}
	}
	if me == nil {
		return Slot{}, false
	}
	p := parentOf(*me, ns)
	if p == nil {
		s.Alone = true
		return s, true
	}
	k := kidsOf(*p, ns)
	if len(k) != 2 {
		return Slot{}, false
	}
	other := k[0]
	s.First = k[0].id == pane
	if s.First {
		other = k[1]
	}
	t := treeOf(other, ns)
	if t == nil {
		return Slot{}, false
	}
	rect := p.rect
	s.Direction, s.Ratio, s.Rect, s.Sibling = p.direction, p.ratio, &rect, t.leaves()
	return s, true
}

// successor is the live member that follows a pane that is gone, by the order saved for
// it, cyclically.
func successor(st State, ws, stack, gone string) string {
	goneOrder := 0
	if m := st.member(gone); m != nil {
		goneOrder = m.Order.int()
	}
	ms := stackPanes(ws, stack)
	for _, m := range ms {
		if m.order() > goneOrder {
			return m.PaneID
		}
	}
	if len(ms) > 0 {
		return ms[0].PaneID
	}
	return ""
}

// build rebuilds a subtree around its first pane, which already fills the subtree's area,
// by moving every other pane back in beside the right one.
func build(t *Tree, tab string) error {
	if t.Pane != "" {
		return nil
	}
	a, b := t.First.leaves()[0], t.Second.leaves()[0]
	if _, err := tryMove(b, "--tab", tab, "--split", t.Direction, "--target-pane", a, "--ratio", ratioArg(t.Ratio), "--no-focus"); err != nil {
		return err
	}
	if err := build(t.First, tab); err != nil {
		return err
	}
	return build(t.Second, tab)
}

// planFor finds where a slot was in a tab whose layout changed when its shown terminal
// went: the panes beside the slot now fill its parent split's rectangle, and when the tab
// was reshaped since the last save the same panes may still be found by name.
func planFor(l Layout, slot Slot) *Tree {
	ns := nodesOf(l)
	live := map[string]bool{}
	for _, n := range ns {
		live[n.id] = true
	}
	var sib []string
	for _, p := range slot.Sibling {
		if live[p] {
			sib = append(sib, p)
		}
	}
	sort.Strings(sib)
	if slot.Rect != nil {
		for _, n := range ns {
			if n.rect == *slot.Rect {
				return treeOf(n, ns)
			}
		}
	}
	if len(sib) == 0 {
		return nil
	}
	for _, n := range ns {
		t := treeOf(n, ns)
		if t == nil {
			continue
		}
		got := t.leaves()
		sort.Strings(got)
		if strings.Join(got, "\n") == strings.Join(sib, "\n") {
			return t
		}
	}
	return nil
}

// refill rebuilds a slot whose shown terminal is gone around the stack's next terminal,
// in the area herdr gave to the panes beside it.
func refill(st State, slot Slot, gone string) {
	ws, tab := slot.Workspace, slot.Tab
	t := successor(st, ws, slot.Stack, gone)
	if t == "" {
		return
	}
	defer relayout(t)
	any := firstPaneIn(ws, tab)
	// A slot alone in its tab took the tab with it, so the next terminal opens in a tab of
	// its own. A tab gone with other panes was closed on purpose, and its stack stays parked.
	if any == "" {
		if !slot.Alone {
			return
		}
		if _, err := tryMove(t, "--new-tab", "--workspace", ws, "--focus"); err != nil {
			notify("스택을 새 탭에 열지 못했습니다", "남은 터미널은 "+parkLabel+" 탭에 있습니다")
		}
		return
	}
	l, err := layoutOf(any)
	if err != nil {
		return
	}
	plan := planFor(l, slot)
	if plan == nil {
		if err := besideLargest(ws, t, tab, "--focus"); err != nil {
			notify("스택 자리를 되살리지 못했습니다", "남은 터미널은 "+parkLabel+" 탭에 있습니다")
		}
		notify("스택 자리를 찾지 못했습니다", "다음 터미널을 가장 큰 pane 옆에 열었습니다")
		return
	}
	leaves := plan.leaves()
	anchor := leaves[0]
	// Every other pane of the subtree waits in its own tab while the slot is cut back in.
	hold := ""
	for _, held := range leaves[1:] {
		if hold == "" {
			h, err := tryMove(held, "--new-tab", "--workspace", ws, "--label", holdLabel, "--no-focus")
			if err != nil {
				notify("스택 자리를 되살리지 못했습니다", err.Error())
				return
			}
			hold = h
			continue
		}
		if err := besideLargest(ws, held, hold, "--no-focus"); err != nil {
			notify("스택 자리를 되살리지 못했습니다", "pane 일부가 "+holdLabel+" 탭에 있습니다")
			return
		}
	}
	if _, err := tryMove(t, "--tab", tab, "--split", slot.Direction, "--target-pane", anchor, "--ratio", ratioArg(slot.Ratio), "--focus"); err != nil {
		notify("스택 자리를 되살리지 못했습니다", err.Error())
		return
	}
	if slot.First {
		if err := trySwap(t, anchor); err != nil {
			notify("스택 자리를 되살리지 못했습니다", err.Error())
		}
	}
	if err := build(plan, tab); err != nil {
		notify("옆 pane 배치를 되살리지 못했습니다", err.Error()+" (일부가 "+holdLabel+" 탭에 있습니다)")
	}
}
