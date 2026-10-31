# Lead: list registered teammates with their task and whether their tab is still alive.
param([string]$Root = (Get-Location).Path)
. "$PSScriptRoot\common.ps1"

$dir = Join-Path (Get-AgentsDir $Root) 'teammates'
if (-not (Test-Path $dir)) { 'No teammates registered.'; return }
Get-ChildItem $dir -Filter '*.json' | ForEach-Object {
    $w = Get-Content -Raw -Encoding UTF8 $_.FullName | ConvertFrom-Json
    $alive = [bool]($w.hostPid -and (Get-Process -Id $w.hostPid -ErrorAction SilentlyContinue))
    [pscustomobject]@{ Name = $w.name; Status = $w.status; Alive = $alive; Task = $w.task }
} | Format-Table -AutoSize | Out-String -Width 200
