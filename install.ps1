# Installs the lead skill on Windows: installs missing requirements with winget (Git for Windows,
# whose Git Bash runs the skill's hook and teammate status line commands; Windows Terminal), checks
# for claude and the wrapup skill, then copies this folder to ~\.claude\skills\lead, keeping the
# runtime state\ already there.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
$dest = Join-Path $HOME '.claude\skills\lead'

function Test-GitBash {
    if ($env:CLAUDE_CODE_GIT_BASH_PATH -and (Test-Path $env:CLAUDE_CODE_GIT_BASH_PATH)) { return $true }
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git -and (Test-Path (Join-Path (Split-Path (Split-Path $git.Source)) 'bin\bash.exe'))) { return $true }
    return (Test-Path (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'))
}

function Install-WithWinget([string]$Id, [string]$What) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "$What is missing and winget is not available: install it by hand, then run this again."
    }
    Write-Host "Installing $What ..."
    winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget could not install $What (exit code $LASTEXITCODE)." }
    $script:restart = $true
}

$script:restart = $false
if (-not (Test-GitBash)) { Install-WithWinget 'Git.Git' 'Git for Windows (Git Bash)' }
if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) { Install-WithWinget 'Microsoft.WindowsTerminal' 'Windows Terminal' }
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Warning "'claude' is not on PATH; teammates need it." }
if (-not (Test-Path (Join-Path $HOME '.claude\skills\wrapup\SKILL.md'))) {
    Write-Warning 'No wrapup skill at ~\.claude\skills\wrapup; teammate wrap-up reads it.'
}

if ((Resolve-Path $src).Path -ne $dest) {
    New-Item -ItemType Directory -Force $dest | Out-Null
    Get-ChildItem -Force $src | Where-Object { $_.Name -notin '.git', 'state' } |
        Copy-Item -Destination $dest -Recurse -Force
}
Write-Host "Installed to $dest"
if ($script:restart) { Write-Host 'Open a new terminal and restart Claude Code so the new programs are on PATH.' }
