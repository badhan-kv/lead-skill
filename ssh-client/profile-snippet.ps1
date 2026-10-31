# Add to your PowerShell profile (notepad $PROFILE) and replace user@host with your Linux machine's
# SSH target: plain "ssh user@host" then goes through lead-ssh.ps1, so lead teammates get their own
# tabs. Any other ssh use is unchanged.
function ssh {
    if ($args.Count -eq 1 -and $args[0] -eq 'user@host') {
        powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\lead-ssh.ps1" $args[0]
    } else {
        ssh.exe @args
    }
}
