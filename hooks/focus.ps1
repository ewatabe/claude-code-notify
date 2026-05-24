param([string]$Url)

if (-not $Url) { exit }
$project = $Url -replace '^claudecode-focus:', '' -replace '^//', ''
try { $project = [System.Uri]::UnescapeDataString($project) } catch {}
if (-not $project) { exit }

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WF {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="GetWindowTextW")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll", EntryPoint="GetWindowTextLengthW")]
    public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);
}
"@ -ErrorAction SilentlyContinue

$script:found = [IntPtr]::Zero
$callback = [WF+EnumWindowsProc] {
    param($hWnd, $lParam)
    if (-not [WF]::IsWindowVisible($hWnd)) { return $true }
    $len = [WF]::GetWindowTextLength($hWnd)
    if ($len -eq 0) { return $true }
    $sb = New-Object System.Text.StringBuilder ($len + 1)
    [void][WF]::GetWindowText($hWnd, $sb, $sb.Capacity)
    $title = $sb.ToString()
    if ($title.IndexOf($project, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $script:found = $hWnd
        return $false
    }
    return $true
}
[void][WF]::EnumWindows($callback, [IntPtr]::Zero)

if ($script:found -ne [IntPtr]::Zero) {
    if ([WF]::IsIconic($script:found)) {
        [void][WF]::ShowWindow($script:found, 9)
    }
    [WF]::keybd_event(0x12, 0, 0, 0)
    [WF]::keybd_event(0x12, 0, 0x0002, 0)
    [void][WF]::SetForegroundWindow($script:found)
}