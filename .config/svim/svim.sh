#!/bin/sh
# SketchyVim supplies MODE=N/I/V/C/_, or an empty MODE when inactive.
set -eu
umask 077

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cache_dir=${SVIM_OVERLAY_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/svim-overlay}
source_file="$config_dir/overlay.m"
binary="$cache_dir/overlay"
mkdir -p "$cache_dir"

case "${1-}" in
  '') mode=${MODE-} ;;
  --stop) mode=stop ;;
  --build) mode= ;;
  *) printf 'Usage: %s [--build | --stop]\n' "$0" >&2; exit 2 ;;
esac

# Atomic replacement lets the overlay always read a complete mode. Write before
# building so changes during the first compilation are not lost.
if [ "${1-}" != --build ]; then
  state_tmp=$(mktemp "$cache_dir/mode.XXXXXX")
  printf '%s\n' "$mode" > "$state_tmp"
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
