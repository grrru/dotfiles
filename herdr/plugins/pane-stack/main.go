// pane-stack lets several terminals take turns in one pane slot: they form the slot's
// stack, and one of them is shown.
//
//	pane-stack new            add a shell to this pane's stack and park this pane
//	pane-stack next | prev    show the stack's next or previous terminal in the slot
//	pane-stack close          close this terminal and show the stack's next one
//	pane-stack goto <pane>    show that terminal of this pane's stack
//	pane-stack drop <pane>    close that terminal of this pane's stack (the shown one as close does)
//	pane-stack pick           list the slot's stack in a herdr popup (plugin action)
//	pane-stack picker         the popup itself
//	pane-stack hook           handle the herdr event in $HERDR_PLUGIN_EVENT (event hooks)
//	pane-stack restore        re-tag stacks from the state file after a server restart
//
// A stack is kept on each of its panes as display-only metadata tokens (ps_stack,
// ps_order) from the source dotfiles.pane-stack, so a stack follows its panes when they
// move. Terminals not shown wait in their workspace's "⧉ pane-stack" tab; herdr closes
// that tab when it empties and the next park opens it again.
//
// Switching moves the incoming pane in beside the current one, then parks the current one.
// Herdr collapses the split the parked pane leaves, so the incoming pane gets the slot's
// exact rectangle and no other split changes. If the second move fails, both stay visible;
// only close and drop close a pane.
//
// When the shown terminal exits or is closed some other way, herdr has already collapsed
// its slot by the time the event hook runs. So every action, and every pane creation or
// move in a workspace with a slot, saves where each slot sits (parent split, side, ratio,
// rectangle, and the panes beside it) to $STATE_DIR/stacks.json, and the hook rebuilds the
// slot there around the next terminal.
//
// Herdr also drops pane metadata when its server restarts while it restores pane ids; the
// startup hook runs restore to re-tag the panes from the same file.
//
// The current pane is $HERDR_ACTIVE_PANE_ID (shell binding), $HERDR_PANE_ID (plugin
// action), or the focused pane. PANE_STACK_NOTIFY=0 turns off herdr notifications.
package main

import (
	"fmt"
	"os"
)

const usage = `pane-stack new | next | prev | close | goto <pane> | drop <pane>
pane-stack pick | picker | hook | restore
`

func main() {
	setup()
	os.Exit(dispatch(os.Args[1:]))
}

func dispatch(args []string) int {
	cmd, target := "", ""
	switch len(args) {
	case 1:
		cmd = args[0]
	case 2:
		cmd, target = args[0], args[1]
	}
	needsTarget := cmd == "goto" || cmd == "drop" || cmd == "preview"
	if cmd == "" || needsTarget != (target != "") {
		fmt.Fprint(os.Stderr, usage)
		return 2
	}
	switch cmd {
	case "hook":
		cmdHook()
		return 0
	case "restore":
		lock()
		defer unlock()
		cmdRestore()
		save()
		return 0
	case "pick":
		return cmdPick()
	case "picker":
		return cmdPicker()
	case "preview":
		return cmdPreview(target)
	case "new", "next", "prev", "close", "goto", "drop":
	default:
		fmt.Fprint(os.Stderr, usage)
		return 2
	}
	lock()
	defer unlock()
	c := load(currentPane())
	switch cmd {
	case "new":
		c.cmdNew()
	case "next":
		c.cmdSwitch(1)
	case "prev":
		c.cmdSwitch(-1)
	case "close":
		c.cmdClose()
	case "goto":
		c.cmdGoto(target)
	case "drop":
		c.cmdDrop(target)
	}
	if p := firstPaneIn(c.W, c.Tab); p != "" {
		relayout(p)
	}
	save()
	return 0
}
