# macOS

[Back to README](../README.md)

## Korean input

The macOS 27 built-in 2-Set Korean input source re-inserts the last jamo on backspace
in Ghostty and kitty, so use [Gureum](https://github.com/gureum/gureum)
(`brew install --cask gureumkim`) instead.

On macOS, `./install.sh config` installs `LaunchAgents/com.github.grrru.dotfiles.keymap.plist`,
which remaps right Command to F19 with `hidutil` at login. Set Gureum's Korean/English
toggle shortcut to F19. Because the key is no longer a modifier, typing quickly after
toggling can't trigger Command shortcuts such as `Cmd-D`. To undo the mapping for the
current session, run `hidutil property --set '{"UserKeyMapping":[]}'`.
