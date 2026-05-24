param([string]$Title = 'Claude Code')

[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
$input_json = [Console]::In.ReadToEnd()
$data = $null
try { $data = $input_json | ConvertFrom-Json } catch {}

if ($data.tool_name -eq 'AskUserQuestion') {
    $Title = $Title -replace '権限確認', '質問'
}

$body = ""
$project = ""

if ($data.last_assistant_message) {
    $body = [string]$data.last_assistant_message
} elseif ($data.message) {
    $body = [string]$data.message
} elseif ($data.tool_name) {
    $detail = $null
    if ($data.tool_input) {
        if ($data.tool_name -eq 'AskUserQuestion' -and $data.tool_input.questions -and $data.tool_input.questions.Count -gt 0) {
            $detail = [string]$data.tool_input.questions[0].question
        }
        elseif ($data.tool_input.question) { $detail = [string]$data.tool_input.question }
        elseif ($data.tool_input.command) { $detail = [string]$data.tool_input.command }
        elseif ($data.tool_input.file_path) { $detail = [string]$data.tool_input.file_path }
        elseif ($data.tool_input.description) { $detail = [string]$data.tool_input.description }
    }
    if ($detail) { $body = "$($data.tool_name): $detail" }
    else { $body = "ツール: $($data.tool_name)" }
}

try {
    if (-not $body -and $data.transcript_path -and (Test-Path $data.transcript_path)) {
        $lines = Get-Content $data.transcript_path -Encoding utf8
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            $entry = $null
            try { $entry = $lines[$i] | ConvertFrom-Json } catch { continue }
            if ($entry.type -ne "assistant") { continue }
            if ($entry.isMeta) { continue }
            $content_inner = $entry.message.content
            $textValue = $null
            if ($content_inner -is [string]) {
                $textValue = $content_inner
            } else {
                foreach ($item in $content_inner) {
                    if ($item.type -eq "text") { $textValue = $item.text; break }
                }
            }
            if ($textValue) { $body = $textValue.Trim(); break }
        }
    }
} catch {}

try {
    if ($data.cwd) {
        $project = Split-Path $data.cwd -Leaf
    } elseif ($data.transcript_path -and (Test-Path $data.transcript_path)) {
        $first = Get-Content $data.transcript_path -TotalCount 1 -Encoding utf8 | ConvertFrom-Json
        if ($first.cwd) { $project = Split-Path $first.cwd -Leaf }
    }
} catch {}

if (-not $body) { $body = "(内容なし)" }
$body = ($body -replace "\s+", " ").Trim()
if ($body.Length -gt 120) { $body = $body.Substring(0, 117) + "..." }

$finalTitle = $Title
if ($project) { $finalTitle = "$Title [$project]" }

$iconPath = Join-Path $PSScriptRoot "claude-code-bell-256.png"
$focusScript = Join-Path $PSScriptRoot "focus.ps1"

$AppId = "Anthropic.ClaudeCode.Notify"
try {
    $regPath = "HKCU:\Software\Classes\AppUserModelId\$AppId"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "Claude Code"
    if (Test-Path $iconPath) {
        Set-ItemProperty -Path $regPath -Name "IconUri" -Value $iconPath
    }
} catch {}

try {
    $protoPath = "HKCU:\Software\Classes\claudecode-focus"
    if (-not (Test-Path $protoPath)) { New-Item -Path $protoPath -Force | Out-Null }
    Set-ItemProperty -Path $protoPath -Name "(default)" -Value "URL:Claude Code Focus"
    Set-ItemProperty -Path $protoPath -Name "URL Protocol" -Value ""
    $cmdPath = "$protoPath\shell\open\command"
    if (-not (Test-Path $cmdPath)) { New-Item -Path $cmdPath -Force | Out-Null }
    $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$focusScript`" `"%1`""
    Set-ItemProperty -Path $cmdPath -Name "(default)" -Value $cmd
} catch {}

try {
    $null = [Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime]
    $null = [Windows.UI.Notifications.ToastNotification,Windows.UI.Notifications,ContentType=WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument,Windows.Data.Xml.Dom.XmlDocument,ContentType=WindowsRuntime]

    $titleEsc = [System.Security.SecurityElement]::Escape($finalTitle)
    $bodyEsc = [System.Security.SecurityElement]::Escape($body)

    $launchAttr = ""
    if ($project) {
        $launchArg = [System.Uri]::EscapeDataString($project)
        $launchUrl = [System.Security.SecurityElement]::Escape("claudecode-focus:$launchArg")
        $launchAttr = " launch=`"$launchUrl`" activationType=`"protocol`""
    }

    $imageNode = ""
    if (Test-Path $iconPath) {
        $iconUri = "file:///" + $iconPath.Replace('\', '/')
        $imageNode = "<image placement=`"appLogoOverride`" hint-crop=`"default`" src=`"$iconUri`"/>"
    }

    $xmlString = "<toast$launchAttr><visual><binding template=`"ToastGeneric`"><text>$titleEsc</text><text>$bodyEsc</text>$imageNode</binding></visual></toast>"

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($xmlString)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
} catch {}