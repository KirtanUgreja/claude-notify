#!/bin/sh
# Claude Prompt Notifier — plays a sound + desktop notification when Claude waits.
# Notification-only. Never exits non-zero; missing tools degrade to silence.

TITLE="Claude Code Waiting"
BODY="Claude is requesting your permission."

# --test: same code path as a real hook fire, but says what it detected.
[ "$1" = "--test" ] && echo "notify.sh: uname=$(uname -s)"

notify_macos() {
  # Notification first (fast), then sound in the background so nothing waits on afplay.
  command -v osascript >/dev/null 2>&1 && \
    osascript -e "display notification \"$BODY\" with title \"$TITLE\"" >/dev/null 2>&1
  if [ -f /System/Library/Sounds/Glass.aiff ]; then
    # Fully detach: hook runners wait on the process tree, so a plain `&` child
    # still blocks them for afplay's ~2.4s. nohup + disown orphans it.
    nohup afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
}

notify_linux() {
  # Sound: first available player on a common system sound; fall back to terminal bell.
  snd="/usr/share/sounds/freedesktop/stereo/complete.oga"
  if command -v paplay >/dev/null 2>&1 && [ -f "$snd" ]; then
    paplay "$snd" >/dev/null 2>&1 &
  elif command -v aplay >/dev/null 2>&1 && [ -f /usr/share/sounds/alsa/Front_Center.wav ]; then
    aplay /usr/share/sounds/alsa/Front_Center.wav >/dev/null 2>&1 &
  else
    printf '\a'
  fi
  command -v notify-send >/dev/null 2>&1 && notify-send "$TITLE" "$BODY" >/dev/null 2>&1
}

notify_windows() {
  # Git Bash ships with Claude Code on Windows, so this script is the single
  # cross-platform entry point; hand off to PowerShell for sound + toast.
  # Path must be Windows-native (C:\...) — powershell.exe can't read /c/... .
  ps1=$(cd "$(dirname "$0")" && pwd -W 2>/dev/null || cd "$(dirname "$0")" && pwd)
  ps1="$ps1/notify.ps1"
  command -v powershell.exe >/dev/null 2>&1 || { printf '\a'; return; }
  if [ "$1" = "--test" ]; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ps1" -Test
  else
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ps1" >/dev/null 2>&1
  fi
}

case "$(uname -s)" in
  Darwin)                    notify_macos ;;
  Linux)                     notify_linux ;;
  MINGW*|MSYS*|CYGWIN*)      notify_windows "$1" ;;
  *)                         printf '\a' ;;  # unknown POSIX: terminal bell, best effort
esac

exit 0
