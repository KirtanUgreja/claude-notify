# claude-notify (Windows) - sound + toast when Claude Code wants you.
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
# When notify.sh is the caller it has already prefixed the title, so skip -
# otherwise the project name would appear twice.
if ($env:CLAUDE_PROJECT_DIR -and $Title -notmatch " - ") {
  try {
    $project = Split-Path -Leaf $env:CLAUDE_PROJECT_DIR
    if ($project) { $Title = "$project - $Title" }
  } catch { }
}

# Sound: play the system WAV if present, else console beep.
# PlaySync, not Play - Play() is async and the script exits before it is heard.
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

# Toast: real Action Center toast under PowerShell's own registered AUMID.
# A bare NotifyIcon balloon (the old approach) comes from an unregistered,
# short-lived process, and Windows 10/11 silently drops those regardless of
# code correctness - confirmed via trace logging: the balloon path ran to
# completion with no error, yet never appeared. Borrowing the AUMID that
# Windows already has registered for powershell.exe puts the toast through
# the same path as any other trusted app, so it isn't filtered.
if (-not $Silent) {
  $toastOk = $false
  try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
      [Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $text = $template.GetElementsByTagName("text")
    $text.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null
    $text.Item(1).AppendChild($template.CreateTextNode($Body)) | Out-Null
    $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
    $aumid = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($aumid).Show($toast)
    $toastOk = $true
  } catch { if ($Test) { Write-Host "toast (Action Center) failed: $_" } }

  # Fallback for machines where the WinRT toast API itself is unavailable.
  if (-not $toastOk) {
    try {
      Add-Type -AssemblyName System.Windows.Forms
      Add-Type -AssemblyName System.Drawing
      $n = New-Object System.Windows.Forms.NotifyIcon
      $n.Icon = [System.Drawing.SystemIcons]::Information
      $n.Visible = $true
      $n.ShowBalloonTip(5000, $Title, $Body, [System.Windows.Forms.ToolTipIcon]::Info)
      # The balloon needs the owning process alive to render.
      Start-Sleep -Seconds 3
      $n.Dispose()
    } catch { if ($Test) { Write-Host "toast (balloon fallback) failed: $_" } }
  }
}

if ($Test) { Write-Host "claude-notify: kind=$Kind title=$Title" }
exit 0
