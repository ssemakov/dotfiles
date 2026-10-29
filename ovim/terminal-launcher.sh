#!/usr/bin/env bash
# Enable "Use custom launcher script" in ovim. Its fallthrough callback cannot
# pass shell environment changes back to ovim, so launch Alacritty here.
set -euo pipefail

# Finder-launched apps do not necessarily inherit the shell's Homebrew PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export NVIM_APPNAME=nvim-ovim

: "${OVIM_CLI:?Run this script through ovim}"
: "${OVIM_SESSION_ID:?Missing ovim edit session}"
: "${OVIM_FILE:?Missing ovim temporary file}"
: "${OVIM_SOCKET:?Missing ovim RPC socket}"

terminal_path="/Applications/Alacritty.app/Contents/MacOS/alacritty"
if [ ! -x "$terminal_path" ]; then
  terminal_path="$(command -v alacritty)"
fi
editor_path="${OVIM_EDITOR:-nvim}"
title="ovim-edit-$OVIM_SESSION_ID"

args=(
  --title "$title"
  --option 'window.dynamic_title=false'
  --option 'window.startup_mode="Windowed"'
)

# Approximate cell dimensions for startup; set exact bounds through AX below.
if [[ "${OVIM_WIDTH:-}" =~ ^[0-9]+$ ]] && [ "$OVIM_WIDTH" -gt 0 ]; then
  columns=$((OVIM_WIDTH / 8))
  [ "$columns" -ge 40 ] || columns=40
  args+=(--option "window.dimensions.columns=$columns")
fi
if [[ "${OVIM_HEIGHT:-}" =~ ^[0-9]+$ ]] && [ "$OVIM_HEIGHT" -gt 0 ]; then
  lines=$((OVIM_HEIGHT / 16))
  [ "$lines" -ge 10 ] || lines=10
  args+=(--option "window.dimensions.lines=$lines")
fi

"$terminal_path" "${args[@]}" -e "$editor_path" --listen "$OVIM_SOCKET" -- "$OVIM_FILE" &
terminal_pid=$!

# This dedicated Alacritty process lives until nvim exits or its window closes.
# Tracking it lets ovim detect both exits and keep its normal text handoff.
if ! "$OVIM_CLI" launcher-handled --session "$OVIM_SESSION_ID" --pid "$terminal_pid"; then
  kill "$terminal_pid" 2>/dev/null || true
  wait "$terminal_pid" 2>/dev/null || true
  exit 1
fi

# ovim's geometry is in macOS screen points. AX avoids assuming a Retina scale.
# Positioning is best effort; editing still works without AX permission here.
if [ -n "${OVIM_X:-}" ] && [ -n "${OVIM_Y:-}" ] &&
  [ -n "${OVIM_WIDTH:-}" ] && [ -n "${OVIM_HEIGHT:-}" ]; then
  /usr/bin/osascript - "$terminal_pid" "$OVIM_X" "$OVIM_Y" "$OVIM_WIDTH" "$OVIM_HEIGHT" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set targetPID to item 1 of argv as integer
  set popupX to item 2 of argv as integer
  set popupY to item 3 of argv as integer
  set popupWidth to item 4 of argv as integer
  set popupHeight to item 5 of argv as integer
  tell application "System Events"
    repeat 40 times
      set matches to application processes whose unix id is targetPID
      if (count of matches) > 0 then
        set terminalProcess to item 1 of matches
        if (count of windows of terminalProcess) > 0 then
          tell terminalProcess
            set position of window 1 to {popupX, popupY}
            set size of window 1 to {popupWidth, popupHeight}
            set frontmost to true
          end tell
          exit repeat
        end if
      end if
      delay 0.05
    end repeat
  end tell
end run
APPLESCRIPT
fi

wait "$terminal_pid"
