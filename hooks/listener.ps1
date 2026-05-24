param(
    [int]$Port = 7474,
    [string]$BindHost = 'localhost'
)

$ErrorActionPreference = 'Continue'
$notifyScript = Join-Path $PSScriptRoot 'notify.ps1'
if (-not (Test-Path $notifyScript)) {
    Write-Error "notify.ps1 not found at $notifyScript"
    exit 1
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://${BindHost}:${Port}/")
try {
    $listener.Start()
    Write-Host "claude-code-notify listener started on http://${BindHost}:${Port}/notify"
    Write-Host "Forwarding to: $notifyScript"
} catch {
    Write-Error "Failed to start listener: $_"
    exit 1
}

try {
    while ($listener.IsListening) {
        try { $context = $listener.GetContext() } catch { break }
        $req = $context.Request
        $res = $context.Response
        try {
            if ($req.Url.AbsolutePath -eq '/notify' -and $req.HttpMethod -eq 'POST') {
                $title = $req.Headers['X-Claude-Title']
                if (-not $title) { $title = 'Claude Code' }
                $title = $title -replace '[`"]', ''

                $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                $body = $reader.ReadToEnd()
                $reader.Close()

                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = 'powershell.exe'
                $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$notifyScript`" -Title `"$title`""
                $psi.UseShellExecute = $false
                $psi.RedirectStandardInput = $true
                $psi.CreateNoWindow = $true

                $p = [System.Diagnostics.Process]::Start($psi)
                $writer = New-Object System.IO.StreamWriter($p.StandardInput.BaseStream, [System.Text.UTF8Encoding]::new($false))
                $writer.Write($body)
                $writer.Flush()
                $writer.Close()

                $res.StatusCode = 200
                $okBytes = [byte[]]@(0x4F, 0x4B)
                $res.ContentLength64 = $okBytes.Length
                $res.OutputStream.Write($okBytes, 0, $okBytes.Length)
            } else {
                $res.StatusCode = 404
            }
        } catch {
            Write-Host "Error: $_"
            try { $res.StatusCode = 500 } catch {}
        } finally {
            try { $res.Close() } catch {}
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}