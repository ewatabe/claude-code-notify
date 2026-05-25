<#
.SYNOPSIS
    Install or remove the auto-start shortcut for claude-code-notify listener.

.DESCRIPTION
    Creates a shortcut under the current user's Startup folder so that listener.ps1
    runs hidden at every logon. No admin privileges required.

.PARAMETER Remove
    Remove the shortcut instead of installing it.

.EXAMPLE
    .\install-listener.ps1
    .\install-listener.ps1 -Remove
#>
param([switch]$Remove)

$listenerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "hooks\listener.ps1"
$shortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\claude-code-notify-listener.lnk"

if ($Remove) {
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        Write-Host "Removed: $shortcutPath"
    } else {
        Write-Host "Shortcut not present: $shortcutPath"
    }
    exit 0
}

if (-not (Test-Path $listenerPath)) {
    Write-Error "listener.ps1 not found at $listenerPath"
    exit 1
}

$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($shortcutPath)
$sc.TargetPath = "powershell.exe"
$sc.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$listenerPath`""
$sc.WorkingDirectory = Split-Path $listenerPath
$sc.WindowStyle = 7
$sc.Description = "Claude Code notify listener (auto-start)"
$sc.Save()

Write-Host "Installed shortcut: $shortcutPath"
Write-Host "Target: $listenerPath"
Write-Host ""
Write-Host "To start the listener immediately (without rebooting):"
Write-Host "  Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','`"$listenerPath`"'"