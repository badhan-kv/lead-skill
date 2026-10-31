# Hook script (teammate sessions only): turns a permission prompt, dialog or API error into an
# event file the lead's watcher picks up. One file per event, so simultaneous events never collide.
param([string]$Kind = 'event')
. "$PSScriptRoot\common.ps1"

$raw = [Console]::In.ReadToEnd()
$j = $null
try { $j = $raw | ConvertFrom-Json } catch {}

$root = $env:AGENT_ROOT
if (-not $root -and $j) { $root = $j.cwd }
if (-not $root) { exit 0 }
$name = $env:AGENT_NAME
if (-not $name) { $name = 'unknown-teammate' }

$type = ''
$msg = ''
if ($j) {
    foreach ($p in 'notification_type', 'error_type', 'matcher', 'reason') {
        if ($j.PSObject.Properties[$p] -and $j.$p) { $type = [string]$j.$p; break }
    }
    foreach ($p in 'message', 'error', 'error_message', 'title') {
        if ($j.PSObject.Properties[$p] -and $j.$p) { $msg = [string]$j.$p; break }
    }
    # PermissionRequest: say exactly what is waiting for approval.
    if ($j.hook_event_name -eq 'PermissionRequest') {
        $type = 'permission'
        $ti = $j.tool_input
        $detail = ''
        if ($ti) {
            foreach ($p in 'command', 'file_path', 'url', 'path', 'pattern') {
                if ($ti.PSObject.Properties[$p] -and $ti.$p) { $detail = [string]$ti.$p; break }
            }
            if (-not $detail) { $detail = ($ti | ConvertTo-Json -Compress -Depth 3) }
        }
        $detail = ($detail -replace '\s+', ' ')
        if ($detail.Length -gt 200) { $detail = $detail.Substring(0, 200) + '...' }
        $msg = "wants to use $($j.tool_name): $detail"
    }
}
# Print nothing: this hook only observes and must not answer the permission request.

$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss-fff')
$file = Join-Path (Get-AgentsDir $root) "events\$stamp-$name-$Kind-$([guid]::NewGuid().ToString('N').Substring(0,6)).json"
Write-Utf8NoBom $file (([pscustomobject]@{
    time    = (Get-Date).ToString('s')
    teammate  = $name
    kind    = $Kind
    type    = $type
    message = $msg
}) | ConvertTo-Json)
exit 0
