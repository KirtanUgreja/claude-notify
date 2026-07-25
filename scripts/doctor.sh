#!/bin/sh
# claude-notify doctor — checks each layer separately so a failure points at one
# thing. Run on the machine where notifications aren't appearing:
#
#   sh scripts/doctor.sh
#
# Paste the whole output when reporting a problem.

echo "==================== claude-notify doctor ===================="
echo

echo "--- 1. environment ---"
echo "uname            : $(uname -s 2>/dev/null || echo '(uname missing)')"
echo "shell            : ${SHELL:-unset}"
echo "OS               : ${OS:-unset}"
echo "CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-unset}"
echo "CLAUDE_PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT:-unset}"
echo "script dir       : $(cd "$(dirname "$0")" 2>/dev/null && pwd)"
echo "windows path form: $(cd "$(dirname "$0")" 2>/dev/null && { pwd -W 2>/dev/null || echo '(pwd -W unsupported — expected off Windows)'; })"
echo "notify config    : OFF=${CLAUDE_NOTIFY_OFF:-0} QUIET=${CLAUDE_NOTIFY_QUIET:-0} SILENT=${CLAUDE_NOTIFY_SILENT:-0} SOUND=${CLAUDE_NOTIFY_SOUND:-default}"
echo

echo "--- 2. files present ---"
dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
for f in notify.sh notify.ps1; do
  if [ -f "$dir/$f" ]; then echo "ok      : $f"; else echo "MISSING : $f"; fi
done
echo

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *)
    echo "--- not Windows: running notify.sh directly ---"
    sh "$dir/notify.sh" permission --test </dev/null
    echo
    echo "Did you hear a sound and see a banner? If not, the problem is this"
    echo "platform's notification tools, not the Windows path."
    exit 0 ;;
esac

echo "--- 3. powershell reachable ---"
if command -v powershell.exe >/dev/null 2>&1; then
  echo "ok      : powershell.exe on PATH"
  powershell.exe -NoProfile -Command '"ok      : powershell runs, version " + $PSVersionTable.PSVersion' 2>&1 | head -2
else
  echo "MISSING : powershell.exe not on PATH  <-- nothing can work without this"
  exit 1
fi
echo

echo "--- 4. is there an interactive desktop session? ---"
# A hook running without a visible desktop can play no sound and show no toast,
# no matter how correct the code is.
powershell.exe -NoProfile -Command '
  "user            : " + [Environment]::UserName
  "session id      : " + (Get-Process -Id $PID).SessionId
  "interactive     : " + [Environment]::UserInteractive
  "session 0 means services-only: no sound, no toast, ever."
' 2>&1 | head -5
echo

echo "--- 5. sound file present ---"
powershell.exe -NoProfile -Command '
  $w = "$env:WINDIR\Media\Windows Notify.wav"
  if (Test-Path $w) { "ok      : $w" } else { "MISSING : $w (falls back to console beep)" }
' 2>&1 | head -2
echo

echo "--- 6. sound alone (listen now) ---"
powershell.exe -NoProfile -Command '
  try {
    $w = "$env:WINDIR\Media\Windows Notify.wav"
    if (Test-Path $w) { (New-Object System.Media.SoundPlayer $w).PlaySync(); "played  : WAV finished" }
    else { [console]::beep(880,300); "played  : console beep" }
  } catch { "FAILED  : $_" }
' 2>&1 | head -3
echo

echo "--- 7. toast alone (watch the tray) ---"
powershell.exe -NoProfile -Command '
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $n = New-Object System.Windows.Forms.NotifyIcon
    $n.Icon = [System.Drawing.SystemIcons]::Information
    $n.Visible = $true
    $n.ShowBalloonTip(5000,"claude-notify doctor","If you can read this, toasts work.",
                      [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 4
    $n.Dispose()
    "shown   : no error raised (may still be suppressed by Focus assist)"
  } catch { "FAILED  : $_" }
' 2>&1 | head -3
echo

echo "--- 8. full chain via notify.sh ---"
sh "$dir/notify.sh" permission --test </dev/null 2>&1 | head -5
echo

echo "==================== what your answers mean ===================="
echo "6 played but silent   -> volume/output device, or Focus assist muting"
echo "7 shown but invisible -> Settings > System > Notifications (app: Windows"
echo "                         PowerShell) or Focus assist is suppressing it"
echo "4 says session 0      -> hook has no desktop; nothing can appear"
echo "8 errors but 6+7 fine -> bug in notify.sh dispatch; send this output"
echo "==============================================================="
