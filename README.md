# claude-notify

Plays a sound and shows a desktop notification when Claude Code is waiting for your
permission or input — so you don't leave it hanging while you're heads-down elsewhere.

Works on **macOS, Linux, and Windows**. No dependencies, no network, no telemetry,
fully offline. Uses only built-in OS tools.

**Notification-only.** It never approves, denies, or interacts with Claude.

## Install

```
/plugin marketplace add KirtanUgreja/claude-notify
/plugin install claude-notify@claude-notify
```

Then restart Claude Code, or start a new session.

Same two commands on every platform — no paths to edit, no `settings.json` to
hand-write.

## Verify

```sh
sh scripts/notify.sh --test
```

Prints the detected platform and runs the same code path a real hook fires, so you
should hear the sound and see a banner. On Windows it prints `sound failed:` or
`toast failed:` if a channel breaks, instead of failing silently.

## How it works

Claude Code fires its built-in [`Notification`
hook](https://code.claude.com/docs/en/hooks) exactly when it needs your attention.
The plugin registers one hook entry pointing at `scripts/notify.sh`, which detects
the OS and dispatches:

| OS | Sound | Notification |
|---|---|---|
| macOS | `afplay` on `Glass.aiff` | `osascript` banner |
| Linux | `paplay`, falling back to `aplay` | `notify-send` |
| Windows | `Media.SoundPlayer` on `Windows Notify.wav` | WinForms balloon tip |

No polling, no terminal scraping, no false positives.

If a sound or notification tool isn't available, that channel is skipped silently —
the script always exits 0 and never interferes with your Claude session.

### Windows notes

`notify.sh` is the single entry point on all three platforms. On Windows, Claude
Code runs it under the Git Bash it ships with; the script detects
`MINGW*`/`MSYS*`/`CYGWIN*` and hands off to `notify.ps1` via `powershell.exe`.

This avoids two traps that break hand-written Windows hooks:

- **Shell-form hook commands run through `cmd.exe`,** not PowerShell — so a bare
  `powershell -File C:\...` hook command is parsed by cmd and is fragile.
- **Backslash paths in JSON.** `"C:\path\to\x.ps1"` is invalid JSON (`\p` isn't a
  valid escape) and makes the *entire* settings file fail to parse, so no hooks load
  at all. The plugin uses `${CLAUDE_PLUGIN_ROOT}` and sidesteps this.

The Windows balloon tip uses `NotifyIcon`, which Windows 10/11 can suppress
depending on your notification settings. If `--test` reports no error but you see no
banner, check Settings → System → Notifications.

## Layout

```
.claude-plugin/plugin.json    plugin manifest
hooks/hooks.json              registers the Notification hook
scripts/notify.sh             entry point: macOS, Linux, Windows dispatch
scripts/notify.ps1            Windows sound + toast
```

## License

MIT — see [LICENSE](LICENSE).
