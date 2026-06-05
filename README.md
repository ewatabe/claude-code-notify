# claude-code-notify

<img src="hooks/claude-code-bell-256.png" width="96" align="right" alt="">

Windows toast notifications for [Claude Code](https://code.claude.com/). Get a desktop alert when Claude finishes a task or needs your input — whether Claude Code runs on your Windows machine **or on a remote Linux host** (EC2 / WSL2 / any SSH target).

## Highlights

- **Zero dependencies.** Uses raw WinRT toast APIs directly — no BurntToast, no PSGallery module.
- **Remote-friendly.** Ships with a tiny HTTP listener so remote Linux hooks can light up Windows toasts via an SSH port forward.
- **Click-to-focus.** Clicking the toast brings the matching VS Code window to the front.
- **Contextual.** Title shows the project name; body shows a preview of Claude's last response (or the tool being requested).
- **UTF-8 throughout.** Toast body survives Unicode end-to-end (Japanese, emoji, etc.).

## Install

In Claude Code:

```
/plugin marketplace add ewatabe/claude-code-notify
/plugin install claude-code-notify@claude-code-notify
```

That's it for the Windows-native case. New sessions get toast notifications automatically.

## WSL2 (Claude Code in WSL on the same Windows machine)

**Nothing to configure.** When the plugin runs inside WSL2 on the same PC as Windows, `notify.sh` calls `notify.ps1` directly through `powershell.exe` interop (`wslpath` translates the script path automatically). No listener, no SSH tunnel, and **no mirrored networking** needed — toasts work out of the box after install.

> ⚠️ **Do not enable `networkingMode=mirrored` for this.** It is unnecessary here, and in corporate / VPN / proxy environments it commonly breaks WSL2's outbound connectivity — including Claude Code's own connection to the Anthropic API. The interop path above avoids `localhost` entirely, so mirrored mode buys you nothing.

If toasts don't appear, verify interop reaches PowerShell:

```bash
grep -qiE 'microsoft|wsl' /proc/version && command -v powershell.exe && echo "interop OK"
```

## Remote setups (Linux / EC2 over SSH — no Windows interop)

When Claude Code runs on a remote host with no Windows interop, PowerShell isn't reachable there — the plugin POSTs to a listener on your Windows client, tunneled back over SSH.

**1. On the remote** — install the plugin (same one-liner as above).

**2. On the Windows client** — set the listener to auto-start at logon:

```powershell
& "$env:USERPROFILE\.claude\plugins\marketplaces\claude-code-notify\tools\install-listener.ps1"
```

(No admin required. Creates a shortcut in the Startup folder. Use `-Remove` later to undo.)

To start it immediately without rebooting:

```powershell
Start-Process powershell -WindowStyle Hidden -ArgumentList @(
  '-NoProfile','-ExecutionPolicy','Bypass','-File',
  "$env:USERPROFILE\.claude\plugins\marketplaces\claude-code-notify\hooks\listener.ps1"
)
```

**3. SSH port forward** — add to `~/.ssh/config` on the Windows client:

```
Host my-remote
    HostName <host-or-tailscale-name>
    User <remote-user>
    RemoteForward 7474 localhost:7474
```

**4. Verify** — from the remote shell:

```bash
curl -v http://localhost:7474/
# HTTP/1.1 404 from Microsoft-HTTPAPI/2.0 → listener reachable
```

<details>
<summary><b>WSL2 note</b></summary>

If Claude Code runs in WSL2 on the same machine as Windows, you don't need this SSH/listener setup at all — see [WSL2 (same Windows machine)](#wsl2-claude-code-in-wsl-on-the-same-windows-machine) above. The plugin uses `powershell.exe` interop directly. Avoid `networkingMode=mirrored`; it can break outbound connectivity in corporate/VPN environments.

</details>

## What you see

| Hook event | Toast title |
|---|---|
| `Stop` | `Claude Code: Done [project]` |
| `PermissionRequest` | `Claude Code: Permission [project]` |
| `PermissionRequest` (AskUserQuestion) | `Claude Code: Question [project]` |

The body shows a preview of the assistant's response (Stop) or `<tool>: <key argument>` for PermissionRequest (e.g. `Edit: src/foo.ts`, `Bash: git status`, `AskUserQuestion: <question text>`).

Titles are ASCII because HTTP headers can't safely carry non-ASCII bytes; the body is full UTF-8.

## Customizing

- **Icon** — replace `hooks/claude-code-bell-256.png` with your own square PNG (256×256+).
- **Titles** — edit the `-Title` arguments in `hooks/hooks.json`.
- **Listener port** — set `CLAUDE_NOTIFY_PORT` / `CLAUDE_NOTIFY_HOST` env vars on the remote.

## Known limitations

- The `Notification` hook is intentionally not registered — it overlaps with `PermissionRequest` for `AskUserQuestion` and would double-toast. See [dimokol/claude-notifications](https://github.com/dimokol/claude-notifications) for a robust dedup approach if you need idle-state notifications.
- `PermissionRequest` and `Notification` hooks don't fire under the VS Code Native UI — only the terminal UI ([anthropics/claude-code#31285](https://github.com/anthropics/claude-code/issues/31285)). `Stop` notifications still work everywhere.
- Click-to-focus matches windows by title containing the project folder name; very generic names (`src`, `code`) may match unintended windows.

## Uninstall

```
/plugin uninstall claude-code-notify
```

Remove the listener auto-start and registry entries (optional):

```powershell
& "$env:USERPROFILE\.claude\plugins\marketplaces\claude-code-notify\tools\install-listener.ps1" -Remove
Remove-Item "HKCU:\Software\Classes\AppUserModelId\Anthropic.ClaudeCode.Notify" -Recurse
Remove-Item "HKCU:\Software\Classes\claudecode-focus" -Recurse
```

## Prior art

Builds on ideas from existing Claude Code notification projects:

- [dimokol/claude-notifications](https://github.com/dimokol/claude-notifications) — atomic dedup, click-to-focus
- [soulee-dev/claude-code-notify-powershell](https://github.com/soulee-dev/claude-code-notify-powershell) — zero-dep WinRT pattern
- [claudes-world/cctoast-wsl](https://github.com/claudes-world/cctoast-wsl) — WSL → Windows toast
- [777genius/claude-notifications-go](https://github.com/777genius/claude-notifications-go) — cross-platform Go implementation
- [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) — reference for all 13 hook events

## License

MIT
