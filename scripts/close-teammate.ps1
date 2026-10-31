# Lead: close a teammate's session and tab. Send the wrap-up instruction and wait for its DONE first.
param(
    [Parameter(Mandatory)][string]$Name,
    [string]$Root = (Get-Location).Path
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

$Root = (Resolve-Path $Root).Path.TrimEnd('\')
$w = Read-Teammate $Root $Name
if (-not $w) { throw "No teammate '$Name' registered under $Root" }
if (-not $w.hostPid -or -not (Get-Process -Id $w.hostPid -ErrorAction SilentlyContinue)) {
    Set-TeammateField $Root $Name @{ status = 'closed' }
    "Teammate '$Name' is not running (already closed)."
    return
}

# Stop only claude (the tab's child process); run-teammate.ps1 then exits cleanly and the tab closes.
$kids = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($w.hostPid)" |
    Where-Object { $_.Name -eq 'claude.exe' }
foreach ($k in $kids) { Stop-Process -Id $k.ProcessId -Force -ErrorAction SilentlyContinue }

$deadline = (Get-Date).AddSeconds(15)
while ((Get-Process -Id $w.hostPid -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 300
}
if (Get-Process -Id $w.hostPid -ErrorAction SilentlyContinue) {
    Stop-Process -Id $w.hostPid -Force -ErrorAction SilentlyContinue
    Set-TeammateField $Root $Name @{ status = 'closed'; ended = (Get-Date).ToString('s') }
    "Teammate '$Name' tab host did not exit on its own; it was force-stopped (tab may show an exit message)."
} else {
    "Closed teammate '$Name'."
}
