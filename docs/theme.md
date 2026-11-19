# Theme switching

[Back to README](../README.md)

Run the script from Bash or Zsh:

```sh
toggle-theme            # flip light <-> dark
toggle-theme light      # force a mode
toggle-theme --apply    # re-apply the current mode (use after editing theme.conf)
```

Every theme setting lives in two files in the dotfiles root, and `toggle-theme` is the
only thing that reads them:

| File | Tracked | Holds |
| --- | --- | --- |
| `theme.defaults.conf` | yes | every key with its default (Catppuccin Latte / Frappe) |
| `theme.conf` | no (git-ignored) | only the keys that differ on this machine |

From those the script generates one file per tool and never reads them back, apart from
the mode. All of them are rewritten on every run, so hand-edits do not survive.

| Generated | Read by |
| --- | --- |
| `ghostty/theme.local` | Ghostty (`config-file`); on macOS the script reloads Ghostty through AppleScript |
| `~/.theme_mode` | Neovim, through a file watcher: the mode and the colorscheme |
| `theme` in `~/.claude/settings.json` | Claude Code, at startup |
| `name` in `herdr/config.toml` | herdr: the server reloads it for pane borders, and the script presses the client's reload key through Ghostty |

Claude Code's theme defaults to `auto`, which follows the terminal's background in
running sessions too: `toggle-theme` tells claude panes under herdr that the theme
changed, and Neovim does the same for claude in its terminal buffers. With a fixed theme
name such as `light-daltonized`, only sessions started after the toggle change.

While a herdr client runs, `toggle-theme` also runs, with the same mode, on every enabled
saved herdr machine (`THEME_HERDR_MACHINES`), so their Neovims, pane borders, and Claude
Code panes switch too.

## Per-machine themes

Put only what differs into `theme.conf`, then run `toggle-theme --apply`:

```sh
# ~/dotfiles/theme.conf
GHOSTTY_DARK_THEME="NightFox"
NVIM_DARK_COLORSCHEME="nightfox"
```

`theme.defaults.conf` documents every key; changing a value there changes the default on
every machine. The script looks for the override in `$DOTFILES_THEME_CONF`,
`<dotfiles>/theme.conf`, and `~/.config/dotfiles/theme.conf`, in that order; the first
existing file wins.

Neovim colorschemes must come from a plugin it actually loads. This repo ships
catppuccin and nightfox; to use anything else on one machine, drop a lazy.nvim spec into
the git-ignored `gruvim/lua/local/plugins/`, which `init.lua` imports when present:

```lua
-- gruvim/lua/local/plugins/colorscheme.lua
return {
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
}
```

then set `NVIM_DARK_COLORSCHEME="tokyonight"` in `theme.conf`. If a configured
colorscheme cannot be loaded, Neovim warns and falls back to Catppuccin.

## Per-machine Ghostty settings

`ghostty/config` reads two optional files after itself: the generated `theme.local`, and
`local.conf` for everything else that differs per machine. `local.conf` is git-ignored,
hand-written, and read last, so it overrides both:

```sh
# ~/dotfiles/ghostty/local.conf
font-size = 15
```

Ghostty picks it up on the next config reload (`Cmd-Shift-,`, or any `toggle-theme` run,
which touches `ghostty/config`).
