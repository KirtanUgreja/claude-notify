# claude-notify (Windows) — sound + toast when Claude Code wants you.
# Notification-only. Never throws; missing features degrade to silence.
# Normally invoked by notify.sh (the cross-platform entry point), not directly.
param(
  [string]$Title = "Claude needs you",
  [string]$Body  = "Waiting for permission.",
  [string]$Kind  = "permission",
  [string]$Sound = "",
  [switch]$Quiet,
  [switch]$Silent,
  [switch]$Test
)

if ($env:CLAUDE_NOTIFY_OFF -eq "1") { exit 0 }
if ($env:CLAUDE_NOTIFY_QUIET -eq "1")  { $Quiet  = $true }
if ($env:CLAUDE_NOTIFY_SILENT -eq "1") { $Silent = $true }
if ($env:CLAUDE_NOTIFY_SOUND)          { $Sound  = $env:CLAUDE_NOTIFY_SOUND }

# Label with the project name, matching notify.sh. On Windows the hook calls
# this script directly (a bare `sh` cannot be spawned), so the title is built
# here rather than passed in already-labelled.
# When notify.sh is the caller it has already prefixed the title, so skip —
# otherwise the project name would appear twice.
if ($env:CLAUDE_PROJECT_DIR -and $Title -notmatch " — ") {
  try {
    $project = Split-Path -Leaf $env:CLAUDE_PROJECT_DIR
    if ($project) { $Title = "$project — $Title" }
  } catch { }
}

# Sound: play the system WAV if present, else console beep.
# PlaySync, not Play — Play() is async and the script exits before it is heard.
if (-not $Quiet) {
  try {
    $wav = $Sound
    if (-not $wav) {
      # "done" gets a softer sound than the "come back here" events.
      $wav = if ($Kind -eq "done") { "$env:WINDIR\Media\Windows Ding.wav" }
             else                  { "$env:WINDIR\Media\Windows Notify.wav" }
    }
    if (Test-Path $wav) {
      (New-Object System.Media.SoundPlayer $wav).PlaySync()
    } else {
      [console]::beep(880, 300)
    }
  } catch { if ($Test) { Write-Host "sound failed: $_" } }
}

# Toast: balloon tip via WinForms (available on all supported Windows).
# System.Drawing must load too — SystemIcons lives there, and without it the
# icon line throws and the whole toast is silently skipped.
if (-not $Silent) {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $n = New-Object System.Windows.Forms.NotifyIcon
    $n.Icon = [System.Drawing.SystemIcons]::Information
    $n.Visible = $true
    $n.ShowBalloonTip(5000, $Title, $Body, [System.Windows.Forms.ToolTipIcon]::Info)
    # The balloon needs the owning process alive to render. The hook runs this
    # async, so the wait costs the user nothing; without it the tip never paints.
    Start-Sleep -Seconds 3
    $n.Dispose()
  } catch { if ($Test) { Write-Host "toast failed: $_" } }
}

if ($Test) { Write-Host "claude-notify: kind=$Kind title=$Title" }
exit 0
