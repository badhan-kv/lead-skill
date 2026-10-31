# Use instead of plain "ssh" from the Windows PC: opens the SSH session as usual and, while it is
# open, opens a view for every lead teammate on the Linux machine: the ones already running, and
# each new one the lead spawns from this SSH session. A teammate's view closes when the teammate ends;
# closing it only closes the view, the teammate keeps running.
# Run inside Windows Terminal: the SSH session stays in the current tab, each teammate gets a tab in
# the same window and focus goes back to tab -LeadTab (default 0, the first tab; Windows Terminal
# cannot open a tab in the background, so focus is moved back by tab number). Run from a classic
# console window with Windows Terminal installed: the SSH session moves to the first tab of a new
# Windows Terminal window. Without Windows Terminal: each teammate gets its own PowerShell window.
# Works over any network path to the host: the SSH session and the tab feed are matched by a random
# id (LEAD_TAB_ID), not by IP address.
# Needs key-based SSH login (the background feed cannot type a password).
# Usage: powershell -ExecutionPolicy Bypass -File lead-ssh.ps1 [user@host]
param(
    [string]$Target = 'user@host',  # set to your Linux machine's SSH target
    [string]$Window = '',  # Windows Terminal window for the teammate tabs ('0' = the current one)
    [int]$LeadTab = 0      # index of the lead tab in that window
)
if ($Target -eq 'user@host') {
    Write-Error 'No SSH target: run lead-ssh.ps1 <user@host>, or set the default of -Target in this file.'
    exit 1
}

$hasWt = [bool](Get-Command wt.exe -ErrorAction SilentlyContinue)

# Already in Windows Terminal: stay in this tab; teammate tabs go into this (most recently used) window.
if ($env:WT_SESSION -and -not $Window) { $Window = '0' }

# Classic console: restart as the first tab of a new, uniquely named Windows Terminal window, so
# teammate tabs can be added to it and focus can go back to tab 0 (the lead tab).
if ($hasWt -and -not $Window) {
    $Window = "lead-$PID"
    Start-Process wt.exe -ArgumentList ("-w $Window new-tab --title lead --suppressApplicationTitle " +
        "powershell -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Target $Target -Window $Window")
    return
}

$tabId = [guid]::NewGuid().ToString('N').Substring(0, 12)

$feed = Start-Job -ArgumentList $Target, $Window, $tabId, $LeadTab -ScriptBlock {
    param($Target, $Window, $tabId, $LeadTab)
    $scripts = '~/.claude/skills/lead/scripts'
    while ($true) {
        ssh.exe -o BatchMode=yes -o ServerAliveInterval=30 $Target "bash $scripts/tab-feed.sh $tabId" | ForEach-Object {
            $p = $_ -split "`t"
            if ($p.Count -ge 3) {
                $sess, $wid, $name = $p[0], $p[1], $p[2]
                $attach = "ssh.exe -t $Target bash $scripts/attach-tab.sh $sess $wid $name"
                if ($Window) {
                    # New tab at the end of the lead window, then focus back on the lead tab.
                    Start-Process wt.exe -ArgumentList ("-w $Window new-tab --title $name " +
                        "--suppressApplicationTitle $attach ; focus-tab -t $LeadTab")
                } else {
                    $cmd = "`$host.UI.RawUI.WindowTitle = '$name'; " +
                           "ssh.exe -t $Target 'bash $scripts/attach-tab.sh $sess $wid $name'"
                    Start-Process powershell -ArgumentList '-NoProfile', '-Command', $cmd
                }
            }
        }
        Start-Sleep -Seconds 5
    }
}

try {
    # Same as a plain login, plus LEAD_TAB_ID so teammates spawned from this session get tabs.
    ssh.exe -t $Target "LEAD_TAB_ID=$tabId exec bash -l"
} finally {
    Stop-Job $feed
    Remove-Job $feed -Force
}
