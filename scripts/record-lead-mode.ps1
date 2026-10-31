# Hook (registered by the lead skill, PreToolUse): records the lead's current permission mode so
# spawn-teammate.ps1 can start teammates in the same mode. Prints nothing and never blocks the tool.
try {
    $j = [Console]::In.ReadToEnd() | ConvertFrom-Json
    if (-not $j.permission_mode -or -not $j.cwd) { exit 0 }
    $f = Join-Path $j.cwd '.agents\lead.json'
    $dir = Split-Path -Parent $f
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $data = [pscustomobject]@{
        sessionId      = $j.session_id
        permissionMode = $j.permission_mode
        updated        = (Get-Date).ToString('s')
    }
    [IO.File]::WriteAllText($f, ($data | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
} catch {}
exit 0
