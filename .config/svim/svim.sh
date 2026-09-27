#!/bin/sh
# SketchyVim supplies MODE and CMDLINE; our Vim hook adds SVIM_CMDTYPE.
set -eu
umask 077

if [ "${1-}" = --setup ]; then
  # Append one idempotent hook, preserving any existing mappings and settings.
  svimrc="$HOME/.config/svim/svimrc"
  hook='autocmd CmdlineEnter * let $SVIM_CMDTYPE = getcmdtype()'
  mkdir -p "$(dirname "$svimrc")"
  if [ ! -f "$svimrc" ] || ! grep -qxF "$hook" "$svimrc"; then
    printf '\n%s\n' "$hook" >> "$svimrc"
  fi
  printf '%s\n' 'Command/search labels enabled. Restart SketchyVim to load the hook.'
  exit 0
fi

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cache_dir=${SVIM_OVERLAY_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/svim-overlay}
source_file="$config_dir/overlay.m"
binary="$cache_dir/overlay"
mkdir -p "$cache_dir"

case "${1-}" in
  '') mode=${MODE-} ;;
  --stop) mode=stop ;;
  --build) mode= ;;
  *) printf 'Usage: %s [--setup | --build | --stop]\n' "$0" >&2; exit 2 ;;
esac

# Only command mode carries text. SketchyVim may leave CMDLINE set after exiting
# a command, so explicitly clear it for badges, inactivity, and shutdown.
command_type=
command_line=
if [ "$mode" = C ]; then
  case "${SVIM_CMDTYPE-}" in
    :|/|'?') command_type=$SVIM_CMDTYPE ;;
  esac
  command_line=${CMDLINE-}
fi

# One atomic record: mode on line 1, command type on line 2, then the verbatim
# command text (which may itself contain newlines). Never evaluate command text.
if [ "${1-}" != --build ]; then
  state_tmp=$(mktemp "$cache_dir/mode.XXXXXX")
  if [ "$mode" = stop ]; then
    # Keep shutdown compatible with an older helper during an upgrade.
    printf 'stop\n' > "$state_tmp"
  else
    printf '%s\n%s\n%s' "$mode" "$command_type" "$command_line" > "$state_tmp"
  fi
  mv -f "$state_tmp" "$cache_dir/mode"
fi
[ "${1-}" != --stop ] || exit 0

if [ ! -x "$binary" ] || [ "$source_file" -nt "$binary" ]; then
  # Other hooks already wrote their latest mode; the first builder will show it.
  if ! mkdir "$cache_dir/build.lock" 2>/dev/null; then
    if [ "${1-}" = --build ]; then
      printf 'Overlay build already running: %s/build.lock\n' "$cache_dir" >&2
      exit 1
    fi
    exit 0
  fi
  build_tmp="$cache_dir/overlay.build.$$"
  trap 'rm -f "$build_tmp"; rmdir "$cache_dir/build.lock"' EXIT
  trap 'exit 1' HUP INT TERM
  /usr/bin/xcrun clang -O2 -fobjc-arc -framework Cocoa \
    "$source_file" -o "$build_tmp"
  mv -f "$build_tmp" "$binary"
fi
[ "${1-}" != --build ] || exit 0

# The helper holds an OS lock: extra invocations exit immediately, and a crash
# releases the lock automatically. Keep SketchyVim's hook short and asynchronous.
/usr/bin/nohup "$binary" "$cache_dir" >/dev/null 2>>"$cache_dir/overlay.log" &
