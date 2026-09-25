# SketchyVim mode overlay

A small, click-through macOS badge appears for 0.9 seconds when SketchyVim
changes mode: green **NORMAL**, blue **INSERT**, purple **VISUAL**, or orange
**COMMAND**. It sits at the bottom center of the display containing the mouse
pointer, works across Spaces, and does not take keyboard focus. An empty mode
(SketchyVim inactive or an unsupported field) hides it immediately.

Uses native AppKit; no SketchyBar or Hammerspoon required. The first invocation
compiles `overlay.m` with Apple's Command Line Tools (`xcode-select --install`
if missing). The executable and runtime files live in `~/.cache/svim-overlay/`
or `$XDG_CACHE_HOME/svim-overlay/`. One helper stays running, sleeping until the
mode file changes; repeated command-line updates do not redisplay the badge.

## Install

The dotfiles `install.sh` taps and trusts `FelixKratz/formulae`, installs
SketchyVim, links the overlay and blacklist on macOS, and sets the macOS
text-selection color to light brown. Existing files are backed up before linking.
To install just this overlay, run from the dotfiles repository (back up an
existing `svim.sh` first):

```sh
mkdir -p ~/.config/svim
ln -s "$PWD/.config/svim/svim.sh" ~/.config/svim/svim.sh
ln -s "$PWD/.config/svim/overlay.m" ~/.config/svim/overlay.m
~/.config/svim/svim.sh --build
MODE=N ~/.config/svim/svim.sh
```

SketchyVim invokes `~/.config/svim/svim.sh` automatically; no service restart is
needed for the overlay. The manual commands above leave existing `svimrc` and
`blacklist` files alone.

## Blacklist and selection color

The included blacklist excludes `Ghostty` (by name and the bundle identifier
`com.mitchellh.ghostty`) and `Obsidian`. SketchyVim compares exact, case-sensitive
app names or bundle identifiers; lowercase `ghostty` does not match `Ghostty`.
Keep one entry per line without surrounding whitespace.
The blacklist is read at startup, so after editing `~/.config/svim/blacklist`, run:

```sh
brew services restart svim
```

Switch to another application and back afterward so the app exclusion is checked.
See [SketchyVim's blacklist implementation](https://github.com/FelixKratz/SketchyVim/blob/master/src/event_tap.c).

If SketchyVim still swallows keys in Ghostty, including `i` in zsh's `/` history
search, temporarily stop it with `brew services stop svim` to confirm the cause.
The blacklist bypasses all keyboard handling for an app; it does not distinguish
the shell prompt from history search. SketchyVim caches this decision from app
activation notifications, so a bundle-ID entry cannot fix stale focus tracking.

As a workaround, enable **Ghostty → Secure Keyboard Entry** in the macOS menu
bar, then start svim again. Ghostty blocks external keyboard monitoring while
active and releases secure input when switching to another app. This also
affects other utilities that monitor keyboard events. Toggle the same menu item
to disable it; the manual setting lasts until Ghostty quits. See
[Ghostty's action reference](https://ghostty.org/docs/config/keybind/reference#toggle_secure_input)
and [focus handling](https://github.com/ghostty-org/ghostty/blob/main/macos/Sources/Features/Secure%20Input/SecureInput.swift).

The installer sets a light-brown selection color (`#D2B48C`). To apply it directly:

```sh
defaults write NSGlobalDomain AppleHighlightColor -string "0.823529 0.705882 0.549020"
```

This is a system-wide text-selection preference. Relaunch affected apps if they
keep displaying the previous color. SketchyVim documents this setting in its
[README](https://github.com/FelixKratz/SketchyVim#installation).

## Preview and customize

```sh
MODE=I ~/.config/svim/svim.sh
MODE=V ~/.config/svim/svim.sh
MODE=C ~/.config/svim/svim.sh
MODE= ~/.config/svim/svim.sh       # hide immediately
~/.config/svim/svim.sh --stop      # stop the helper until the next hook
```

To change the display duration, export `SVIM_OVERLAY_DURATION=1.5` near the top
of `svim.sh`, before launching the helper. Stop the helper first so it picks up
the new setting. Size, colors, and position are in `overlay.m`; stop the helper
before changing that file, and the next hook recompiles it automatically.

For troubleshooting, run `svim.sh --build` in a terminal and inspect
`~/.cache/svim-overlay/overlay.log`. If a build was forcibly killed, remove the
empty `~/.cache/svim-overlay/build.lock` directory before retrying.

The mode values and hook behavior come from
[SketchyVim's hook example](https://github.com/FelixKratz/SketchyVim/blob/master/examples/svim.sh)
and [buffer implementation](https://github.com/FelixKratz/SketchyVim/blob/master/src/buffer.c).
