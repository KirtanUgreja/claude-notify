# claude-notify

Plays a sound and shows a desktop notification when Claude Code is waiting for your
permission or input — so you don't leave it hanging while you're heads-down elsewhere.

Works on **macOS, Linux, and Windows**. No dependencies, no network, no telemetry,
fully offline. Uses only built-in OS tools.

**Notification-only.** It never approves, denies, or interacts with Claude.

Alerts are labelled with the project directory and differ by event, so with several
sessions open you can tell which one wants you — and whether it's blocked or just
finished:

| Event | Alert | Sound |
|---|---|---|
| Needs permission | `my-app — Claude needs you` | Glass / Notify |
| Idle, awaiting a prompt | `my-app — Claude is waiting` | Glass / Notify |
| Finished responding | `my-app — Claude finished` | Tink / Ding (softer) |

## Install

```
/plugin marketplace add KirtanUgreja/claude-notify
/plugin install claude-notify@claude-notify
```

Then restart Claude Code, or start a new session.

Same two commands on every platform — no paths to edit, no `settings.json` to
hand-write.

## Configure

Set these in your shell profile or the `env` block of `settings.json` — no need to
fork the plugin:

| Variable | Effect |
|---|---|
| `CLAUDE_NOTIFY_OFF=1` | Disable entirely |
| `CLAUDE_NOTIFY_QUIET=1` | Banner only, no sound |
| `CLAUDE_NOTIFY_SILENT=1` | Sound only, no banner |
| `CLAUDE_NOTIFY_SOUND=/path/to.aiff` | Use your own sound file |

## Verify

```sh
sh scripts/notify.sh --test              # or: idle / done
```

Prints the detected platform and event, and runs the same code path a real hook
fires — so you should hear the sound and see a banner. On Windows it prints
`sound failed:` or `toast failed:` if a channel breaks, instead of failing silently.

## How it works

Claude Code fires its built-in [`Notification` and `Stop`
hooks](https://code.claude.com/docs/en/hooks) exactly when it needs your attention.
The plugin matches the notification types worth interrupting you for
(`permission_prompt`, `idle_prompt`, `agent_needs_input`, `agent_completed`,
`elicitation_dialog`) and skips the purely informational ones, then runs
`scripts/notify.sh`, which detects the OS and dispatches:

| OS | Sound | Notification |
|---|---|---|
| macOS | `afplay` on `Glass.aiff` / `Tink.aiff` | `osascript` banner |
| Linux | `paplay`, falling back to `aplay` | `notify-send` |
| Windows | `Media.SoundPlayer` on `Windows Notify.wav` | WinForms balloon tip |

Hooks run `async`, so the alert never delays your session. The project name comes
from `CLAUDE_PROJECT_DIR`, falling back to the `cwd` in the hook's stdin payload.

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
