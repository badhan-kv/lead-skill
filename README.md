# lead skill

Run a project as a small team: one **lead** session keeps the big picture and splits the work;
each task runs in a **teammate** session in its own terminal window: a Windows Terminal tab on
Windows, a tmux window on Linux. Teammates do and document the detailed work and report or escalate
to the lead; the lead reports to the user.

## Requirements and install
Get it: `git clone https://github.com/badhan-kv/lead-skill`. The repo and skill were previously called
`boss` / `boss-skill`; the old URL redirects. If you have the old `boss` skill installed, remove
`~/.claude/skills/boss` after installing this one (command `/lead` replaces `/boss`).

One skill for both systems; the lead picks the script set for the machine it runs on.

| | Windows | Linux |
|---|---|---|
| Needs | Git for Windows (Git Bash), Windows Terminal, PowerShell 5.1+ | tmux, jq, bash |
| Install | `powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1` | `bash install.sh` |

Both: Claude Code (`claude` on PATH) and the `wrapup` skill in `~/.claude/skills/wrapup` (teammates
read it when they wrap up). Run the installer from a clone of this repo. It installs missing
requirements (winget on Windows; apt, dnf, pacman or brew on Linux), then copies the skill to
`~/.claude/skills/lead`, keeping that folder's runtime `state/`. Run it again after a `git pull`.

Git Bash is required on Windows because Claude Code runs the skill's hook and the teammate status
line through it; `scripts/run-for-os.sh` then starts the `.ps1` script on Windows or the `.sh`
script on Linux, so those commands are the same on both.

## Use
In a Claude Code session started in the project folder, type:

```
/lead <what the team should work on>
```

The lead reads CHECKPOINT/BACKLOG, agrees the task split with you, then spawns teammates.

- **Managing**: talk to the lead. It answers teammates' questions when it can and brings you the
  rest, including permission prompts (approve those in the named teammate's tab or window).
- **Mode**: teammates start in the lead's permission mode at the time they are spawned.
- **Finishing**: type `/wrapup` in the lead. All teammates wrap up at the same time (each documents
  its work first, editing only its own sections) and each is closed as it finishes; then the lead
  wraps itself up. Close the lead yourself.

Teammate status line: teammate name, task and context use. The lead's own status line can show a gold
`LEAD` marker when `.agents/lead.json` names its session (see `scripts/statusline.*`).

### Windows
- **Watching**: click any teammate tab (coloured, titled with the teammate's name). Opening a teammate
  does not switch you away from your tab.

### Linux
- **Where it runs**: local terminal sessions and SSH sessions alike. Smoothest with the lead
  started inside tmux: teammates then open as windows in the same tmux session, and the lead survives
  a dropped SSH connection.
- **Watching**: teammates live in the lead's tmux session if the lead runs inside tmux, otherwise in
  a detached session `lead-<project>`: `tmux attach -t lead-<project>`. Switch windows with
  Ctrl-b n / p / w. Window names are the teammate names, coloured like their status line.
- **SSH auto-attach** (optional): add to `~/.bashrc`:
  `[ -f "$HOME/.claude/skills/lead/scripts/ssh-login.sh" ] && . "$HOME/.claude/skills/lead/scripts/ssh-login.sh"`.
  On an interactive SSH login outside tmux it reopens windows for running teammates and attaches
  (Ctrl-b d returns to the shell; `LEAD_AUTO_ATTACH=0` turns it off). Projects are remembered in
  `state/roots.txt` when a teammate is spawned there.
- **Teammate tabs on a Windows PC over SSH** (optional): copy `ssh-client/lead-ssh.ps1` to the PC
  (`$HOME\`) and connect with `powershell -ExecutionPolicy Bypass -File lead-ssh.ps1 [user@host]`
  instead of plain `ssh`, or add `ssh-client/profile-snippet.ps1` to the PowerShell profile so
  plain `ssh <user@host>` does that (edit the host in both files). Run inside Windows Terminal, the
  SSH session stays in the current tab and every running teammate, and each teammate the lead spawns
  from it, gets a tab in the same window titled with the teammate name; focus returns to the first
  tab (`-LeadTab N` for another; Windows Terminal cannot open background tabs). From a classic
  console window the SSH session moves to the first tab of a new Windows Terminal window.
  Without Windows Terminal each teammate gets its own PowerShell window. A teammate's tab closes when
  the teammate ends; closing it leaves the teammate running (`scripts/tab-feed.sh` +
  `scripts/attach-tab.sh`). Needs key-based SSH login. Spawns outside SSH are unaffected.
- **Background sessions**: a teammate moved into a Claude background session keeps its window,
  which reattaches (`claude attach`). `scripts/open-windows.sh [--root DIR] [--attach]` reopens
  missing windows; `close-teammate.sh` stops background sessions too.

## Files
- `SKILL.md`: lead role and procedure (`/lead`), plus the hook that records the lead's mode.
- `teammate-role.md`: teammate rules (appended to each teammate's system prompt).
- `teammate-settings.json`: teammate-only status line and hooks (passed with `--settings`).
- `scripts/run-for-os.sh`: runs the `.ps1` or `.sh` script of a given name for this OS.
- `scripts/*.ps1` (Windows) and `scripts/*.sh` (Linux): spawn/run/close/list teammates, event
  watcher, hooks, status line; Linux also the tmux window helpers and the SSH tab feed.
- `ssh-client/`: for a Windows PC that connects to the Linux machine over SSH (`lead-ssh.ps1`,
  `profile-snippet.ps1`).
- `install.ps1`, `install.sh`: installers.
- Per project, `.agents/` (gitignored) holds the runtime state: teammate registry, briefs, task
  files, status-line snapshots, events, `lead.json`.

Design, decisions and test history: `BACKLOG.md`.
