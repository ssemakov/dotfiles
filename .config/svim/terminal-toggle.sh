#!/bin/sh
# Build/install the native Cmd+` wrapper without installing a shortcut manager.
set -eu
umask 077
config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cache_dir=${TERMINAL_TOGGLE_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/terminal-toggle}
app="$cache_dir/Terminal Toggle.app"
binary="$app/Contents/MacOS/terminal-toggle"
label=com.ssemakov.terminal-toggle
agent="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"

source_fingerprint() {
  /usr/bin/shasum -a 256 "$config_dir/terminal-toggle.m" "$config_dir/terminal-toggle.sh"
}

build() {
  fingerprint=$(source_fingerprint)
  if [ -x "$binary" ] && [ -f "$cache_dir/build.sha256" ] \
      && [ "$(cat "$cache_dir/build.sha256")" = "$fingerprint" ] \
      && /usr/bin/codesign --verify --strict "$app" 2>/dev/null; then
    return
  fi
  mkdir -p "$app/Contents/MacOS"
  /usr/bin/xcrun clang -O2 -Wall -Wextra -Wno-deprecated-declarations -fobjc-arc \
    -framework Cocoa -framework Carbon "$config_dir/terminal-toggle.m" -o "$binary.build"
  mv "$binary.build" "$binary"
  cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.ssemakov.terminal-toggle</string>
<key>CFBundleName</key><string>Terminal Toggle</string>
<key>CFBundleExecutable</key><string>terminal-toggle</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
  /usr/bin/codesign --force --sign - --identifier "$label" "$app"
  printf '%s\n' "$fingerprint" > "$cache_dir/build.sha256"
}

case "${1-}" in
  --build) build ;;
  --check|--reload)
    [ -x "$binary" ] || build
    exec "$binary" "$cache_dir" "$1"
    ;;
  --svim-stop|--svim-start)
    # The running helper must match this command protocol. Updating explicitly
    # also gives macOS a chance to request permission for a changed signature.
    if [ ! -x "$binary" ] || [ ! -f "$cache_dir/build.sha256" ] \
      || [ "$(cat "$cache_dir/build.sha256")" != "$(source_fingerprint)" ]; then
      printf 'Update Terminal Toggle first: ~/.config/svim/terminal-toggle.sh --update\n' >&2
      exit 1
    fi
    exec "$binary" "$cache_dir" "$1"
    ;;
  --install|--update)
    # Keep an existing helper alive until its replacement has compiled.
    build
    if [ "$1" = --install ]; then
      "$binary" "$cache_dir" --check
      "$binary" "$cache_dir" --reload
    fi
    # Migrate the earlier helper name, including any unfinished restoration.
    legacy_dir="${XDG_CACHE_HOME:-$HOME/.cache}/svim-quick-terminal"
    legacy_agent="$HOME/Library/LaunchAgents/com.ssemakov.svim-quick-terminal.plist"
    if [ -f "$legacy_agent" ]; then
      /bin/launchctl bootout "$domain/com.ssemakov.svim-quick-terminal" 2>/dev/null || true
      if [ -f "$legacy_dir/recovery.plist" ]; then
        if [ -f "$cache_dir/recovery.plist" ]; then
          printf 'Both helpers have pending recovery; refusing to overwrite either.\n' >&2
          exit 1
        fi
        mv "$legacy_dir/recovery.plist" "$cache_dir/recovery.plist"
      fi
      rm "$legacy_agent"
      rm -rf "$legacy_dir/Svim Quick Terminal.app"
    fi
    /bin/launchctl bootout "$domain/$label" 2>/dev/null || true
    mkdir -p "$(dirname "$agent")"
    /usr/bin/plutil -create xml1 "$agent"
    /usr/bin/plutil -insert Label -string "$label" "$agent"
    /usr/bin/plutil -insert ProgramArguments -json '[]' "$agent"
    /usr/bin/plutil -insert ProgramArguments.0 -string "$binary" "$agent"
    /usr/bin/plutil -insert ProgramArguments.1 -string "$cache_dir" "$agent"
    /usr/libexec/PlistBuddy -c 'Add :ProgramArguments:2 string --run' "$agent"
    /usr/bin/plutil -insert RunAtLoad -bool true "$agent"
    /usr/bin/plutil -insert KeepAlive -bool true "$agent"
    /usr/bin/plutil -insert ThrottleInterval -integer 10 "$agent"
    /usr/bin/plutil -insert StandardOutPath -string "$cache_dir/helper.log" "$agent"
    /usr/bin/plutil -insert StandardErrorPath -string "$cache_dir/helper.log" "$agent"
    /bin/launchctl bootstrap "$domain" "$agent"
    printf 'Installed. Cmd+` now pauses SketchyVim while the quick terminal is open.\n'
    ;;
  --uninstall)
    /bin/launchctl bootout "$domain/$label" 2>/dev/null || true
    # Do not restart the keyboard interceptor while the panel might still be
    # open. Keep recovery state if graceful shutdown could not finish.
    if [ -f "$cache_dir/recovery.plist" ]; then
      printf 'Recovery is pending. Close the quick terminal, run brew services restart svim, then switch apps.\n' >&2
      printf 'Saved service: %s/recovery.plist\n' "$cache_dir" >&2
      exit 1
    fi
    rm -f "$agent"
    printf 'Helper removed. Restore the global toggle_quick_terminal binding in Ghostty to use Cmd+` directly.\n'
    ;;
  --status)
    /bin/launchctl print "$domain/$label"
    ;;
  *) printf 'Usage: %s --build|--check|--reload|--install|--update|--uninstall|--status|--svim-stop|--svim-start\n' "$0" >&2; exit 2 ;;
esac
