#!/bin/sh
# claude-notify — sound + desktop notification when Claude Code wants you.
# Notification-only. Never exits non-zero; missing tools degrade to silence.
#
# Usage: notify.sh [permission|idle|done] [--test]
# Reads the hook's JSON payload on stdin to label the notification with the
# project directory; works fine if stdin is empty (e.g. run by hand).
#
# Config (environment variables):
#   CLAUDE_NOTIFY_QUIET=1    no sound, banner only
#   CLAUDE_NOTIFY_SILENT=1   no banner, sound only
#   CLAUDE_NOTIFY_OFF=1      disable entirely
#   CLAUDE_NOTIFY_SOUND=path override the sound file

[ "$CLAUDE_NOTIFY_OFF" = "1" ] && exit 0

KIND="permission"
case "$1" in
  permission|idle|done) KIND="$1"; shift ;;
esac
[ "$1" = "--test" ] && TEST=1

case "$KIND" in
  permission) TITLE="Claude needs you";  BODY="Waiting for permission." ;;
  idle)       TITLE="Claude is waiting"; BODY="Ready for your next prompt." ;;
  done)       TITLE="Claude finished";   BODY="Response complete." ;;
esac

# Label with the project name so the right window is obvious when several are
# open. Prefer $CLAUDE_PROJECT_DIR; it is set for hooks and costs nothing.
# Otherwise read cwd out of the hook's stdin JSON — but never block waiting for
# it: an open pipe that never closes would hang the session, so cap the read
# with dd and parse whatever arrived. Plain sed, since jq may not be installed.
cwd="$CLAUDE_PROJECT_DIR"
if [ -z "$cwd" ] && [ ! -t 0 ]; then
  cwd=$(dd bs=8192 count=1 2>/dev/null \
        | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -1)
fi
if [ -n "$cwd" ]; then
  project=$(basename "$cwd")
  # ASCII hyphen on Windows: PowerShell 5.1 reads arguments in the system ANSI
  # codepage, which mangles an em-dash into mojibake. Keep the nicer dash where
  # the encoding is dependable.
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) sep="-" ;;
    *)                    sep="—" ;;
  esac
  [ -n "$project" ] && TITLE="$project $sep $TITLE"
fi

[ -n "$TEST" ] && echo "claude-notify: uname=$(uname -s) kind=$KIND title=$TITLE"

play_sound()  { [ "$CLAUDE_NOTIFY_QUIET" = "1" ]  && return 1; return 0; }
show_banner() { [ "$CLAUDE_NOTIFY_SILENT" = "1" ] && return 1; return 0; }

notify_macos() {
  # "done" gets a softer sound than the two "come back here" events.
  snd="$CLAUDE_NOTIFY_SOUND"
  if [ -z "$snd" ]; then
    case "$KIND" in
      done) snd=/System/Library/Sounds/Tink.aiff ;;
      *)    snd=/System/Library/Sounds/Glass.aiff ;;
    esac
  fi
  show_banner && command -v osascript >/dev/null 2>&1 && \
    osascript -e "display notification \"$BODY\" with title \"$TITLE\"" >/dev/null 2>&1
  if play_sound && [ -f "$snd" ]; then
    # Fully detach: hook runners wait on the process tree, so a plain `&` child
    # still blocks them for afplay's ~2.4s. nohup + disown orphans it.
    nohup afplay "$snd" >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
}

notify_linux() {
  if play_sound; then
    snd="$CLAUDE_NOTIFY_SOUND"
    [ -z "$snd" ] && snd="/usr/share/sounds/freedesktop/stereo/complete.oga"
    if command -v paplay >/dev/null 2>&1 && [ -f "$snd" ]; then
      paplay "$snd" >/dev/null 2>&1 &
    elif command -v aplay >/dev/null 2>&1 && [ -f /usr/share/sounds/alsa/Front_Center.wav ]; then
      aplay /usr/share/sounds/alsa/Front_Center.wav >/dev/null 2>&1 &
    else
      printf '\a'
    fi
  fi
  show_banner && command -v notify-send >/dev/null 2>&1 && \
    notify-send "$TITLE" "$BODY" >/dev/null 2>&1
}

notify_windows() {
  # Git Bash ships with Claude Code on Windows, so this script is the single
  # cross-platform entry point; hand off to PowerShell for sound + toast.
  # Path must be Windows-native (C:\...) — powershell.exe can't read /c/... .
  dir=$(cd "$(dirname "$0")" 2>/dev/null && { pwd -W 2>/dev/null || pwd; })
  ps1="$dir/notify.ps1"
  command -v powershell.exe >/dev/null 2>&1 || { printf '\a'; return; }
  set -- -NoProfile -ExecutionPolicy Bypass -File "$ps1" \
         -Title "$TITLE" -Body "$BODY" -Kind "$KIND"
  [ "$CLAUDE_NOTIFY_QUIET" = "1" ]  && set -- "$@" -Quiet
  [ "$CLAUDE_NOTIFY_SILENT" = "1" ] && set -- "$@" -Silent
  [ -n "$CLAUDE_NOTIFY_SOUND" ]     && set -- "$@" -Sound "$CLAUDE_NOTIFY_SOUND"
  if [ -n "$TEST" ]; then
    powershell.exe "$@" -Test
  else
    powershell.exe "$@" >/dev/null 2>&1
  fi
}

case "$(uname -s)" in
  Darwin)               notify_macos ;;
  Linux)                notify_linux ;;
  MINGW*|MSYS*|CYGWIN*) notify_windows ;;
  *)                    play_sound && printf '\a' ;;  # unknown POSIX: bell
esac

exit 0
