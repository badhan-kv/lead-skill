# Lead: background watcher (run under the Monitor tool). Prints one line per teammate event and
# moves the event file to events\seen. Events written while no watcher runs are kept and
# reported on the next start.
param([string]$Root = (Get-Location).Path, [int]$IntervalMs = 1000)
. "$PSScriptRoot\common.ps1"

$events = Join-Path (Get-AgentsDir $Root) 'events'
$seen = Join-Path $events 'seen'
New-Item -ItemType Directory -Force $seen | Out-Null

while ($true) {
    $files = Get-ChildItem -Path $events -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name
    foreach ($f in $files) {
        try {
            $ev = Get-Content -Raw -Encoding UTF8 $f.FullName | ConvertFrom-Json
            $line = "[teammate event] {0} | {1}{2} | {3}" -f $ev.teammate, $ev.kind,
                $(if ($ev.type) { "/$($ev.type)" } else { '' }), $ev.message
        } catch {
            # The hook may still be writing it; try again next round.
            continue
        }
        [Console]::Out.WriteLine($line)
        [Console]::Out.Flush()
        Move-Item -Force $f.FullName (Join-Path $seen $f.Name)
    }
    Start-Sleep -Milliseconds $IntervalMs
}
