#!/bin/bash
# notify.sh - Linux / macOS / WSL hook: deliver a Claude Code hook payload to a Windows toast.
#
# Two transports, auto-selected:
#   * WSL2 (same machine as Windows): call notify.ps1 directly via powershell.exe interop.
#     No HTTP listener, no SSH tunnel, no mirrored networking required — works out of the box.
#   * Remote SSH (no Windows interop available): POST the payload to listener.ps1 running on
#     the Windows client (tunneled back over an SSH RemoteForward).

TITLE="$1"
PORT="${CLAUDE_NOTIFY_PORT:-7474}"
HOST="${CLAUDE_NOTIFY_HOST:-localhost}"

# Read the hook JSON from stdin once — stdin can only be consumed a single time.
PAYLOAD="$(cat)"

# Directory of this script; notify.ps1 lives alongside it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- WSL2 fast path: invoke notify.ps1 directly through Windows interop ---
# Detect WSL, ensure powershell.exe + wslpath are present, then translate the Linux
# script path to a Windows path. -ExecutionPolicy Bypass is required because the script
# may run from a \\wsl.localhost UNC path (Internet/Intranet zone under RemoteSigned).
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null \
   && command -v powershell.exe >/dev/null 2>&1 \
   && command -v wslpath >/dev/null 2>&1; then
    WIN_PS1="$(wslpath -w "${SCRIPT_DIR}/notify.ps1" 2>/dev/null)"
    if [ -n "$WIN_PS1" ]; then
        printf '%s' "$PAYLOAD" | powershell.exe -NoProfile -ExecutionPolicy Bypass \
            -File "$WIN_PS1" -Title "$TITLE" >/dev/null 2>&1 || true
        exit 0
    fi
fi

# --- Remote (SSH) path: POST to the Windows-side listener; never error out the hook ---
printf '%s' "$PAYLOAD" | curl -s -m 2 -X POST "http://${HOST}:${PORT}/notify" \
    -H "X-Claude-Title: ${TITLE}" \
    -H "Content-Type: application/json" \
    --data-binary @- >/dev/null 2>&1 || true
exit 0
