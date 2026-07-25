# Claude Prompt Notifier (Windows) — sound + toast when Claude waits.
# Notification-only. Never throws; missing features degrade to silence.
# Normally invoked by notify.sh (the cross-platform entry point), not directly.
param([switch]$Test)

$title = "Claude Code Waiting"
$body  = "Claude is requesting your permission."

# Sound: play the system notify WAV if present, else console beep.
# PlaySync, not Play — Play() is async and the script exits before it is heard.
try {
  $wav = "$env:WINDIR\Media\Windows Notify.wav"
  if (Test-Path $wav) {
    (New-Object System.Media.SoundPlayer $wav).PlaySync()
  } else {
    [console]::beep(880, 300)
  }
} catch { if ($Test) { Write-Host "sound failed: $_" } }

# Toast: balloon tip via WinForms (available on all supported Windows).
# System.Drawing must load too — SystemIcons lives there, and without it the
# icon line throws and the whole toast is silently skipped.
try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $n = New-Object System.Windows.Forms.NotifyIcon
  $n.Icon = [System.Drawing.SystemIcons]::Information
  $n.Visible = $true
  $n.ShowBalloonTip(5000, $title, $body, [System.Windows.Forms.ToolTipIcon]::Info)
  # Balloon needs the owning process alive to render; disposing after 200ms
  # can kill it before it paints. 3s shows reliably without a long stall.
  Start-Sleep -Seconds 3
  $n.Dispose()
} catch { if ($Test) { Write-Host "toast failed: $_" } }

if ($Test) { Write-Host "notify.ps1: done" }
exit 0
