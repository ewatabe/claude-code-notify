#!/bin/bash
# notify.sh - Linux/macOS hook: forwards Claude Code hook payload to Windows-side listener
# Used in Remote-SSH / WSL setups where the listener.ps1 runs on the Windows client.

TITLE="$1"
PORT="${CLAUDE_NOTIFY_PORT:-7474}"
HOST="${CLAUDE_NOTIFY_HOST:-localhost}"

# POST stdin (JSON) to the listener; never error out the hook.
curl -s -m 2 -X POST "http://${HOST}:${PORT}/notify" \
    -H "X-Claude-Title: ${TITLE}" \
    -H "Content-Type: application/json" \
    --data-binary @- >/dev/null 2>&1 || true
exit 0