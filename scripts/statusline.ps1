# Status line for teammate sessions: teammate name | task | context used.
$j = $null
try { $j = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch {}
$e = [char]27

$name = $env:AGENT_NAME
if (-not $name -and $j) { $name = $j.session_name }
if (-not $name) { $name = 'teammate' }

# Task: the teammate's own .agents\tasks\<name>.txt (first line), else the task given at spawn.
# Name colour: the teammate's tab colour from the registry, else cyan.
$task = ''
$nameColor = "$e[1;36m"
if ($env:AGENT_ROOT) {
    $tf = Join-Path $env:AGENT_ROOT ".agents\tasks\$name.txt"
    $wf = Join-Path $env:AGENT_ROOT ".agents\teammates\$name.json"
    $w = $null
    if (Test-Path $wf) { try { $w = Get-Content -Raw -Encoding UTF8 $wf | ConvertFrom-Json } catch {} }
    if (Test-Path $tf) {
        try { $task = (Get-Content -Encoding UTF8 -TotalCount 1 $tf) } catch {}
    }
    if (-not $task -and $w) { $task = $w.task }
    if ($w -and $w.color -match '^#[0-9A-Fa-f]{6}$') {
        $h = $w.color.Substring(1)
        $nameColor = "$e[1;38;2;{0};{1};{2}m" -f [Convert]::ToInt32($h.Substring(0, 2), 16),
            [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16)
    }
}

$ctx = ''
if ($j -and $j.context_window -and $null -ne $j.context_window.used_percentage) {
    $ctx = ' | ctx {0}%' -f [math]::Round([double]$j.context_window.used_percentage)
}

if ($task) { $line = '{0}{1}{2}[0m | {3}{4}' -f $nameColor, $name, $e, $task, $ctx }
else { $line = '{0}{1}{2}[0m{3}' -f $nameColor, $name, $e, $ctx }
$line

# Keep the last shown line (without colours) so the lead can see what each tab displays.
if ($env:AGENT_ROOT -and $env:AGENT_NAME) {
    try {
        $dir = Join-Path $env:AGENT_ROOT '.agents\statusline'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
        [IO.File]::WriteAllText((Join-Path $dir "$name.txt"), ($line -replace "$e\[[0-9;]*m", ''))
    } catch {}
}
