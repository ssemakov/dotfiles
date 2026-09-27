# SketchyVim mode overlay

A small, click-through macOS badge appears for 0.9 seconds when SketchyVim
enters **NORMAL**, **INSERT**, or **VISUAL** mode. Command mode opens a larger
420 × 104 command bar with live, readable text and Enter/Escape hints:

- `/` shows **SEARCH FORWARD** with a light-brown accent.
- `?` shows **SEARCH BACKWARD** with a light-brown accent.
- `:` shows **COMMAND** with an amber accent.

The bar stays visible while typing, including when the query is empty. Enter or
Escape returns to the small mode badge. Long input shows its ending with an
ellipsis. It sits at the bottom center of the display containing the mouse
pointer and stays on that display while editing. It works across Spaces without
taking keyboard focus. An empty mode (inactive or unsupported field) hides it.

Uses native AppKit; no SketchyBar or Hammerspoon required. The first invocation
compiles `overlay.m` with Apple's Command Line Tools (`xcode-select --install`
if missing). The executable and runtime files live in `~/.cache/svim-overlay/`
or `$XDG_CACHE_HOME/svim-overlay/`. One helper stays running, sleeping until the
state file changes. Command text updates in place; duplicate events do not
redisplay the badge. Command text is cleared from the state file when leaving
command mode.

## Install

The dotfiles `install.sh` taps and trusts `FelixKratz/formulae`, installs
SketchyVim, links the overlay and blacklist on macOS, enables command/search
labels, and sets the macOS text-selection color to light brown. Existing files
are backed up before linking. Existing `svimrc` settings are preserved.
To install or upgrade just this overlay, run from the dotfiles repository.
This backs up the installed hook and helper, then links both to this checkout.
It preserves your blacklist and existing `svimrc` settings:

```sh
mkdir -p ~/.config/svim
.config/svim/svim.sh --stop
svim_backup=$(mktemp -d "$HOME/.config/svim/backup.XXXXXX")
for svim_file in svim.sh overlay.m; do
  svim_target="$HOME/.config/svim/$svim_file"
  if [ -e "$svim_target" ] || [ -L "$svim_target" ]; then
    mv "$svim_target" "$svim_backup/$svim_file"
  fi
  ln -s "$PWD/.config/svim/$svim_file" "$svim_target"
done
~/.config/svim/svim.sh --build
~/.config/svim/svim.sh --setup
brew services restart svim
MODE=N ~/.config/svim/svim.sh
```

SketchyVim invokes `~/.config/svim/svim.sh` automatically. `--setup` appends this
hook to `~/.config/svim/svimrc` once, preserving existing settings:

```vim
autocmd CmdlineEnter * let $SVIM_CMDTYPE = getcmdtype()
```

SketchyVim supplies the command text without its `:`, `/`, or `?` prefix. This
hook exports the type through the environment, so the overlay can distinguish
search from commands without guessing from the text. Until the hook is loaded,
the bar still shows live text with the neutral **COMMAND / SEARCH** label.

If both files are already linked to this checkout, future upgrades only need:

```sh
~/.config/svim/svim.sh --stop
~/.config/svim/svim.sh --build
~/.config/svim/svim.sh --setup
brew services restart svim
```

If `--setup` prints usage showing only `--build | --stop`, the installed hook
is an older copy. Use the install/upgrade block above to update both `svim.sh`
and `overlay.m` before running `--setup`.

The next hook starts the helper. No changes to zsh's search or
Ghostty's Secure Keyboard Entry are needed; this bar displays SketchyVim input
in apps where SketchyVim is enabled.

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
MODE=C SVIM_CMDTYPE=/ CMDLINE='meeting notes' ~/.config/svim/svim.sh
MODE=C SVIM_CMDTYPE='?' CMDLINE='previous match' ~/.config/svim/svim.sh
MODE=C SVIM_CMDTYPE=: CMDLINE='%s/old/new/g' ~/.config/svim/svim.sh
MODE=N ~/.config/svim/svim.sh      # return to the short-lived badge
MODE= ~/.config/svim/svim.sh       # hide immediately
~/.config/svim/svim.sh --stop      # stop the helper until the next hook
```

To change the display duration, export `SVIM_OVERLAY_DURATION=1.5` near the top
of `svim.sh`, before launching the helper. Stop the helper first so it picks up
the new setting. This duration applies to mode badges; the command bar stays
open until command mode ends. Size, colors, and position are in `overlay.m`;
stop the helper before changing that file, and the next hook recompiles it
automatically.

For troubleshooting, run `svim.sh --build` in a terminal and inspect
`~/.cache/svim-overlay/overlay.log`. If a build was forcibly killed, remove the
empty `~/.cache/svim-overlay/build.lock` directory before retrying.

The mode values and hook behavior come from
[SketchyVim's hook example](https://github.com/FelixKratz/SketchyVim/blob/master/examples/svim.sh)
and [buffer implementation](https://github.com/FelixKratz/SketchyVim/blob/master/src/buffer.c).
