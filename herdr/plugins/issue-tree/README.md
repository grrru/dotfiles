# issue-tree

[Back to README](../../../README.md)

A herdr plugin for issue trees: one folder per issue under `WORKTREE`, holding a worktree
of the issue branch (`issue/<number>[-<tag>]`) for each repository involved. It opens a
tree as a herdr workspace with a shell in the issue folder on the left and
`claude agents` on the right.

## Install

```sh
./install.sh           # build and link
./install.sh --build   # build only
```

Building needs Go 1.27.3 or newer. The script finds it on `PATH`, under `~/sdk/go*/`, or in
`/usr/local/go/` even when the shell's `GOROOT` points at an older one;
`ISSUE_TREE_GO=/path/to/go` picks one. Running needs herdr 0.9.5 or newer and fzf 0.58 or
newer. The binary is not tracked, so run the script again after pulling changes. The
dotfiles `install.sh` does not run it.

## Keys

| Key | Action |
| --- | --- |
| `C-a i` | Issue tree list, most recently worked on first |
| `C-a I` | New issue tree form |

In the list:

| Key | Action |
| --- | --- |
| `Enter` | Open the tree's workspace |
| `C-o` | Create a tree |
| `C-r` | Add repositories to the tree |
| `C-e` | Set or clear the tree's issue repository from an issue link or `host/owner/repo` |
| `C-x` | Remove the tree's worktrees and branches, keeping or deleting the remote branch |

When the cleanup would lose uncommitted changes, commits found nowhere else, or other
files in the issue folder, `C-x` lists them and asks for the tree's folder name first.

## Issues and trees

The issue folder's `.issue-tracker` records the issue number, the branch, and the
worktrees. A tree created from an issue link, or given one with `C-e`, also records the
issue's `host/owner/repo` as `ISSUE_REPO`. Issues are told apart by repository and number:
a tree without `ISSUE_REPO` matches only a bare number, and a tree with it matches only a
link to that repository. Folder and branch names carry only the number and tag, so two
issues with the same number need different tags.

## Without a terminal

```sh
./issue-tree setup 42 --tag auth-refactor --repo backend-api --repo frontend
```

This creates the tree, or adds the repositories to the issue's tree with that tag, and
opens it in a new workspace. `--here <pane_id>` turns that pane's workspace into the
tree's workspace instead, `--pane <pane_id>` moves that pane into the new workspace, and
`--no-open` only creates the tree. An agent running in herdr passes its own pane as
`"$HERDR_PANE_ID"`.

## Settings

`WORKTREE` (issue folders) and `WORKSPACE` (repositories, one level below) come from the
herdr server's environment, or from `KEY=VALUE` lines in
`$(herdr plugin config-dir dotfiles.issue-tree)/config.sh`. That file can also set the
right pane's command, its working directory, and the split ratio; the keys are listed at
the top of `main.go`.
