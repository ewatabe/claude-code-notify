# claude-code-notify

Windows toast notifications for [Claude Code](https://code.claude.com/) — fires on `Stop` and `PermissionRequest` hook events. Notifications are automatically suppressed when the corresponding terminal / VS Code window is focused, so you only get pinged when you've alt-tabbed away.

Zero dependencies — uses raw WinRT toast APIs directly (no BurntToast / no PSGallery module required).

![icon](hooks/notify-icon.png)

## Requirements

- Windows 10 / 11
- Windows PowerShell 5.1 (preinstalled) or PowerShell 7+

## Install

In Claude Code:

```
/plugin marketplace add ewatabe/claude-code-notify
/plugin install claude-code-notify@claude-code-notify
```

New sessions will get toast notifications.

## What you see

| Hook event | Title |
|---|---|
| `Stop` | `Claude Code 完了 [project]` |
| `PermissionRequest` (normal tools) | `Claude Code 権限確認 [project]` |
| `PermissionRequest` (AskUserQuestion) | `Claude Code 質問 [project]` |

The body shows:
- **Stop**: a preview of Claude's last response
- **PermissionRequest**: `<tool>: <key argument>` — e.g. `Edit: C:\path\to\file.ps1`, `Bash: git status`, `AskUserQuestion: <question text>`

## Click-to-focus

Clicking the toast brings the corresponding VS Code window to the foreground. The plugin registers a custom protocol `claudecode-focus:` under `HKCU\Software\Classes\` on first run (user-scope only — no admin required). On click, `hooks/focus.ps1` enumerates top-level windows, finds the one whose title contains the project name, and calls `SetForegroundWindow`.

Limitations:
- Works for VS Code (window title contains the open folder name). Other terminals (Windows Terminal, etc.) may not match by title.
- If the project name is generic (e.g. `src`, `code`), it may match an unrelated window.

## Known limitations

- **`Notification` event is NOT registered.** It's redundant with `PermissionRequest` for the `AskUserQuestion` flow and would cause double toasts. If you want idle / waiting-state notifications, see [dimokol/claude-notifications](https://github.com/dimokol/claude-notifications) for a robust dedup approach.
- **VS Code Native UI gap** — `PermissionRequest` and `Notification` hooks do not fire under the VS Code Native UI (only the terminal UI). See [anthropics/claude-code#31285](https://github.com/anthropics/claude-code/issues/31285). `Stop` notifications still work.
- **AppUserModelId is registered on first run** under `HKCU\Software\Classes\AppUserModelId\Anthropic.ClaudeCode.Notify` (user-scope only — no admin required).

## Customizing

Fork and edit `hooks/notify.ps1`. The script reads the hook payload from stdin (JSON) and prioritizes:

1. `last_assistant_message` — Stop event
2. `message` — Notification event
3. `tool_name` + `tool_input` — PermissionRequest event
4. Falls back to parsing `transcript_path`

Swap `hooks/notify-icon.png` for your own 364×364 PNG.

## Prior art

This plugin draws ideas from several existing Claude Code notification projects:

- [dimokol/claude-notifications](https://github.com/dimokol/claude-notifications) — atomic lockfile dedup, click-to-focus
- [soulee-dev/claude-code-notify-powershell](https://github.com/soulee-dev/claude-code-notify-powershell) — zero-dep WinRT pattern
- [claudes-world/cctoast-wsl](https://github.com/claudes-world/cctoast-wsl) — WSL → Windows toast
- [777genius/claude-notifications-go](https://github.com/777genius/claude-notifications-go) — cross-platform Go implementation
- [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) — reference for all 13 hook events

## Uninstall

```
/plugin uninstall claude-code-notify
```

To also remove the registry entries created by the plugin:

```powershell
Remove-Item "HKCU:\Software\Classes\AppUserModelId\Anthropic.ClaudeCode.Notify" -Recurse
Remove-Item "HKCU:\Software\Classes\claudecode-focus" -Recurse
```

## License

MIT
