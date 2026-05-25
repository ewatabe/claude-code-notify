# claude-code-notify

Windows toast notifications for [Claude Code](https://code.claude.com/) — fires on `Stop` and `PermissionRequest` hook events. Clicking the toast brings the corresponding VS Code window to the foreground.

Works for:
- **Windows native** — Claude Code running directly on Windows (PowerShell)
- **Remote setups** — Claude Code on Linux / WSL2 / EC2 via SSH, with a small listener on the Windows side relaying notifications over an SSH port forward

Zero dependencies — uses raw WinRT toast APIs directly (no BurntToast / no PSGallery module required).

![icon](hooks/claude-code-bell-256.png)

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

### Remote setups (VS Code Remote-SSH → Linux / WSL2 / EC2)

When Claude Code runs on a remote Linux host, the hook can't invoke PowerShell directly. Instead, **run the listener on the Windows client and forward port 7474 over SSH back to it**.

#### 1. Install the plugin on the remote (where Claude Code runs)

```
/plugin marketplace add ewatabe/claude-code-notify
/plugin install claude-code-notify@claude-code-notify
```

#### 2. On the Windows client — start `listener.ps1`

Once per session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\plugins\marketplaces\claude-code-notify\hooks\listener.ps1"
```

(adjust the path; check via `/plugin` UI for the exact install location)

Auto-start at logon — run the helper script (no admin required; creates a Startup folder shortcut):

```powershell
& "$env:USERPROFILE\.claude\plugins\marketplaces\claude-code-notify\tools\install-listener.ps1"
```

To remove the auto-start later:

```powershell
& "$env:USERPROFILE\.claude\plugins\marketplaces\claude-code-notify\tools\install-listener.ps1" -Remove
```

#### 3. SSH port forward

Add to the Windows client's `~/.ssh/config`:

```
Host my-remote
    HostName <ip-or-name>
    User <remote-user>
    RemoteForward 7474 localhost:7474
```

Works the same over Tailscale — just use the Tailscale MagicDNS name as `HostName`.

#### 4. Verify

From the remote shell where Claude Code runs:

```bash
curl -v http://localhost:7474/
# Expect: HTTP/1.1 404, Server: Microsoft-HTTPAPI/2.0  → listener reachable ✓
# Or:     curl: Connection refused                       → forward not reaching this shell ✗
```

End-to-end toast test:

```bash
echo '{"last_assistant_message":"テスト","cwd":"/home/me/test"}' | \
  curl -s -X POST http://localhost:7474/notify \
    -H "X-Claude-Title: テスト" \
    -H "Content-Type: application/json" \
    --data-binary @-
```

#### WSL2-specific note

Two sub-cases:

- **SSH server runs inside WSL2** (you SSH directly into WSL2): `localhost:7474` in WSL2 = the forwarded port. Works out of the box.
- **SSH server runs on the Windows host** (you SSH to Windows, then `wsl` into WSL2): the forwarded port lives on the Windows host, not on WSL2's `localhost`. Easiest fix is to enable WSL2 **mirrored networking** so `localhost` is shared. Add to `%USERPROFILE%\.wslconfig` on the remote machine:

  ```ini
  [wsl2]
  networkingMode=mirrored
  ```

  Then `wsl --shutdown` and restart WSL2.

#### Overriding host/port

Set on the remote (e.g. in shell rc):

```bash
export CLAUDE_NOTIFY_HOST=localhost
export CLAUDE_NOTIFY_PORT=7474
```

## What you see

| Hook event | Title |
|---|---|
| `Stop` | `Claude Code: Done [project]` |
| `PermissionRequest` (normal tools) | `Claude Code: Permission [project]` |
| `PermissionRequest` (AskUserQuestion) | `Claude Code: Question [project]` |

Titles are ASCII-only because HTTP headers (used to pass the title across the SSH-forwarded listener) cannot reliably carry non-ASCII bytes. The toast **body** is UTF-8 throughout, so Japanese prompts/responses display correctly.

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

Swap `hooks/claude-code-bell-256.png` for your own square PNG (256×256 or 364×364 recommended).

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
