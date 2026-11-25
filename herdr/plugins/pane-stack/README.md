# pane-stack

[Back to README](../../../README.md)

A herdr plugin that stacks several terminals in one pane slot and shows one of them at a
time. The rest of the tab stays put: with a shell on the left and Claude Code on the
right, the left slot can switch between shells while the right pane never moves or
resizes.

A slot is one pane's place in a tab; its stack is the terminals that take turns there.
"Tab" here always means a herdr tab.

## Install

```sh
./install.sh           # build and link
./install.sh --build   # build only
```

Building needs Go 1.25 or newer. The script finds it on `PATH`, under `~/sdk/go*/`, or in
`/usr/local/go/`; `PANE_STACK_GO=/path/to/go` picks one. Running needs herdr 0.9.5 or
newer, and the stack list needs fzf 0.58 or newer. The binary is not tracked, so run the
script again after pulling changes. The keys are in `herdr/config.toml`.

## Keys

| Key | Action |
| --- | --- |
| `C-a S` | List this pane's stack in a popup, with the screen of the terminal under the cursor |
| `C-a M-c` | Add a shell (in the same directory) to this pane's stack and show it |
| `C-a M-n` / `C-a M-p` | Show the stack's next / previous terminal, wrapping around |
| `C-a M-x` | Close this terminal and show the stack's next one |

In the list:

| Key | Action |
| --- | --- |
| `Enter` | Show the terminal under the cursor. The cursor starts on the one after the shown one |
| `1`–`9` | Show that terminal |
| `C-o` | Add a new terminal to the stack |
| `C-x` | Close the terminal under the cursor and keep the list open |
| `Esc` | Close the list |

The border of every terminal in a stack lists the stack, the shown one in brackets:
`⧉ 1:zsh [2:vim] 3:claude`. A list that does not fit herdr's 80-character title becomes
`⧉ 2/5 vim`. Names are the agent herdr detects or the foreground process, as of the
last switch; the list popup shows them as they are now.

## How it works

Terminals that are not shown wait in a `⧉ pane-stack` tab of the same workspace, so
herdr's tab bar appears while a stack holds more than one terminal. Their processes keep
running there. Herdr closes that tab when it empties and the next switch opens it again.

Switching moves the incoming terminal into the slot beside the current one, then moves
the current one to the parking tab. Herdr collapses the split it leaves, so the incoming
terminal gets the slot's exact size and no other pane changes. Herdr does not resize the
terminals a move touches until its next layout pass, so every action ends with a resize
by nothing, which runs one. Programs in a parked
terminal see the parking tab's size until they come back. All parked terminals of a
workspace share that tab, so the more there are, the smaller each one is there.

`new` on a pane parks that pane as the stack's first terminal. After `new` on both panes
of a two-pane tab, the parking tab holds both original terminals side by side and looks
like the old tab, while the visible tab shows the two new shells.

When the shown terminal ends some other way (`exit`, `C-a x`), herdr has already given
its space to the panes beside it, so the plugin's event hook cuts the slot back in
around the stack's next terminal: beside the one pane that took the space, or by holding
a multi-pane neighbour in a `⧉ pane-stack (정리 중)` tab for a moment and rebuilding it
as it was. Every action, and every pane creation or move in a workspace with a slot,
saves where each slot sits for this. When the surroundings changed so much that neither
the slot's old rectangle nor the panes beside it can be found, the next terminal opens
beside the largest pane instead, with a notification.

A stack is kept as metadata on each of its panes, so a stack follows its panes when they
move. Herdr drops that metadata when its server restarts, so the plugin's state file
also keeps the stacks and the startup hook restores them.

The list's preview shows a terminal's screen at that terminal's own size, which in the
parking tab can be much wider than the preview. It drops the blank rows and columns
around the content and centers what a full-screen program had centered, so a dashboard
stays in view; a shell's screen keeps its last rows.

The list popup has no pane of its own in herdr's API, so the `pick` action hands it the
pane it was opened from. The popup runs the same actions as the keys on that pane
(`goto` and `drop` take the terminal to act on) and closes after a switch or a new
terminal.

## Limits

- The keys refuse a pane without a stack and a zoomed tab. On a pane in the parking tab
  they act on its stack's shown terminal, so a key pressed again during a switch still
  counts, and refuse when the stack shows none.
- A stack lives in one workspace.
- Resizing alone saves nothing, so a slot refilled after a resize comes back at the
  ratio saved at the last action, pane creation, or pane move.
- Closing the tab or workspace that holds a slot does not reopen its parked terminals:
  they stay in the parking tab, or close with the workspace.
- Digits in the list pick terminals, so they cannot be typed into its search.

## Tests

```sh
go test ./...
./install.sh --build && tests/live.sh
```

The live tests start a private herdr server under a temporary directory, so they leave
the session they run in alone. They drive the list by running the popup's program in a
plain pane, because keys cannot be sent to a popup. Herdr sizes no terminal while no
client draws it, so the terminal size tests run a herdr client in a private tmux, and are
skipped without tmux.
