# Lead skill — backlog

Goal: `/lead <instructions>` turns a session into a lead that keeps the big picture
and delegates tasks to teammate sessions, each running in its own Windows Terminal tab. Teammates do
the detailed work, document it, report and escalate to the lead; the lead reports to the user.
Two levels only for now (lead → teammates). Teammates may use ordinary in-session subagents.

## Design (decided 2026-10-25)
- One skill folder `~/.claude/skills/lead/`; nothing in global CLAUDE.md or settings.
- Teammates: interactive `claude` sessions launched by `scripts/spawn-teammate.ps1` via
  `wt.exe -w 0 new-tab`, each running `scripts/run-teammate.ps1`, which sets env vars
  (`AGENT_NAME`, `AGENT_LEAD`, `AGENT_ROOT`, `AGENT_SKILL_DIR`), records its PID, and starts
  `claude --name <teammate> --settings teammate-settings.json --append-system-prompt <teammate-role.md>`.
- Teammate-only settings (`teammate-settings.json`, passed with `--settings`): status line (teammate
  name + task + context %) and hooks (permission prompt / dialog, API error) that write event files.
- Communication: cross-session messaging (`SendMessage`) teammate ↔ lead. Teammates prefer the lead;
  teammate ↔ teammate only when needed.
- Escalation of things a teammate cannot message about itself (permission prompt, API error): hook →
  `.agents/events/*.json` → lead's background watcher (`scripts/watch-events.ps1` under Monitor).
  One file per event, so simultaneous events are never lost; the lead batches them for the user.
- The lead cannot approve a teammate's permission prompt (blocked by design); it tells the user
  which tab needs attention. Teammates default to auto mode, so prompts are rare.
- Closing: lead sends a wrap-up instruction → teammate runs the `wrapup` skill, replies DONE → lead
  runs `scripts/close-teammate.ps1`, which stops the teammate's `claude` process; `run-teammate.ps1`
  exits cleanly and the tab closes. The user closes the lead.
- Docs: teammates document their own nitty-gritty. Shared docs are changed only with Edit (never a
  whole-file Write); each agent edits its own story's section. CHECKPOINT.md has one `## <agent>`
  section per agent; the lead owns `## lead`.
- Per-project runtime state in `.agents/` (gitignored): `teammates/<name>.json` registry,
  `briefs/<name>.md`, `events/`.
- Change 2026-10-27: the skill now runs on Linux too (story 8) and both versions are one skill
  folder (story 9). Previously (above) Windows only: PowerShell scripts, Windows Terminal tabs, and
  hook/status line commands with the fixed path `C:/Users/K.Badhan/...`.

## Background and options weighed (2026-10-25)
- Purpose: keep the coordinating session's context small (it holds the big picture only) so more
  of a large project fits in one session, while teammates handle the detail, in parallel where
  possible. The user wants to watch every teammate live in its own tab and manage everything from
  the lead.
- Built-in Claude Code agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) were considered and
  not used: split panes need tmux or iTerm2 (not supported in Windows Terminal), teammates cannot
  have their own teammates, teams do not survive a session resume, and the lead is fixed.
  Cross-session messaging between ordinary sessions (`SendMessage`/`ListAgents`, named pipe on
  Windows) gives separate tabs and named addressing instead.
- Levels: two for now (lead -> teammates). Teammates may use ordinary in-session subagents for
  subtasks; a third level of visible sessions was deferred.
- Shared docs: the user wanted teammates to document their own details (the lead does not know
  them) rather than the lead being the only writer. Options weighed: check-out/check-in locking
  vs edit discipline. Tested: the Edit tool replaces an exact text snippet in the file as it is on
  disk, so two agents editing different places both keep their changes; if the snippet changed,
  the Edit fails and the agent re-reads. Chosen: Edit-only on shared docs (never a whole-file
  Write), each agent edits its own story's section, one CHECKPOINT section per agent. A locking
  hook can be added later if real conflicts appear.
- Wrap-up: a slash command sent from another session arrives as plain text and never runs, so the
  lead sends a WRAPUP instruction and the teammate runs the `wrapup` skill itself. For that the
  `wrapup` skill no longer has `disable-model-invocation`; its description limits it to the user
  typing `/wrapup` or a lead's wrap-up instruction.
  Changed 2026-10-27: see the change entry under story 5 (skill kept manual-only; teammates read and
  follow its "Team mode" section; all teammates wrap up at once).
- Permissions: a message from another session can never approve a permission prompt (by design),
  so the lead reports which teammate tab needs the user. The user mostly runs auto mode, so prompts
  are rare.
- Simultaneous events/questions: one event file per event and a queue of incoming messages per
  session, so nothing is lost; the lead gives the user one combined list tagged by teammate.
- Closing: only the lead closes teammates (after `DONE wrapup`); only the user closes the lead.

## Windows Terminal / environment gotchas (found 2026-10-25)
- `wt.exe` treats `;` as a separator between its own commands, also inside a tab's command line:
  values passed to `spawn-teammate.ps1` and any test command lines must not contain `;`.
- A tab opened from a Claude command inherits that command's environment unless
  `--reloadEnvironment` is given (`NO_COLOR=1`, session identity, git prompt settings).
- Windows Terminal cannot recolour an existing tab from a program, and always focuses a new tab
  (worked around with `focus-tab -t <index>`).
- All tabs share one Windows Terminal process, so a tab's closing cannot be seen from process
  IDs; the open tab titles can be listed with UI Automation
  (`CASCADIA_HOSTING_WINDOW_CLASS` window, `TabItem` elements).
- Windows PowerShell 5.1 shows UTF-8 files without a BOM wrongly with plain `Get-Content`
  (use `-Encoding UTF8`); the files themselves are fine.
- Auto mode blocks commands that look like weakening security (e.g. a teammate running a script with
  `-ExecutionPolicy Bypass`), so teammates update their status line by writing a file instead.
- Testing a lead from another Claude session: launch it with `wt new-tab --reloadEnvironment`,
  otherwise it inherits the launching session's identity and `NO_COLOR`.

## Stories
1. [x] Launcher: `spawn-teammate.ps1`, `run-teammate.ps1`, shared helpers; teammate opens in a named tab.
   - Change 2026-10-25 (found in trial): a tab opened with `wt.exe` inherits the lead's environment,
     including its session identity (`CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_CHILD_SESSION`,
     `CLAUDE_CODE_MESSAGING_SOCKET`/`_TOKEN`, `CLAUDECODE`, `CLAUDE_PID`, ...). The teammate then
     ran as a child of the lead: no entry in `~/.claude/sessions/`, so it could not be messaged
     by name, and it could see the lead's messaging token. Previously `run-teammate.ps1` passed the
     environment through unchanged; now it removes those variables before starting `claude`.
     Verified: the next teammate registered as `teammate-y` and was messaged by name.
2. [x] Teammate status line: name + task (+ context %); `set-task.ps1` to change the task.
   - Change 2026-10-25 (found in trial): auto mode blocked teammates running `set-task.ps1`
     (`powershell -ExecutionPolicy Bypass ...`, classified as weakening security). Previously the
     task was changed by that script (above). Now the teammate overwrites its own
     `.agents/tasks/<name>.txt` with its file tools; the status line shows that file's first line,
     falling back to the task given at spawn. `set-task.ps1` was removed. Verified in trial.
3. [x] Escalation events: `notify-lead.ps1` hook, `watch-events.ps1` watcher, `teammate-settings.json`.
   - Change 2026-10-25 (found in trial): permission prompts were caught with the `Notification`
     hook (`permission_prompt` matcher). The live trial showed it works, but its text is only
     "Claude needs your permission" (no tool or command), and the docs say it fires only after
     the prompt has waited ~6 s. Now permission prompts use the `PermissionRequest` hook, which
     fires as the prompt appears and carries `tool_name`/`tool_input`; the event reads e.g.
     `wants to use Bash: npm install left-pad`. The hook prints nothing, so the dialog is
     unchanged. `Notification` is kept only for elicitation dialogs.
4. [x] Roles: `SKILL.md` (lead, `/lead <instructions>`), `teammate-role.md`.
5. [x] Wrap-up and close: `close-teammate.ps1`, `list-teammates.ps1`; `wrapup` skill team-mode section.
   - Change 2026-10-27 (found in tests on the Linux machine): the published `wrapup` skill
     (private-claude-skills repo) still had `disable-model-invocation: true` and no team-mode
     section, so teammates could not run it and wrapped up by hand. Its step 2 ("overwrite
     CHECKPOINT.md") and step 1 (create `DECISIONS.md` if missing) would also clash with other
     teammates wrapping up at the same time. Previously (see "Background and options weighed",
     Wrap-up bullet): the lead sent `WRAPUP: run the wrapup skill now`, and the skill was to be
     model-invocable. Now `wrapup` keeps `disable-model-invocation` (only the user starts it) and
     gets a "Team mode" section; WRAPUP and `teammate-role.md` tell the teammate to read
     `~/.claude/skills/wrapup/SKILL.md` and follow it as a teammate. Teammate rules: Edit only (never a
     whole-file Write) on shared files, own sections only, own `## <name>` CHECKPOINT section only,
     no new shared files (notes without a fitting doc go to `.agents/wrapup/<name>.md`), never
     commit. Lead rules: send WRAPUP to all teammates at once (not one at a time, so wrap-up is fast
     enough before shutting the computer down), close each as `DONE wrapup` arrives, then fold
     teammate notes in and write CHECKPOINT with only `## lead`. One-at-a-time wrap-up was weighed
     and rejected as too slow.
6. [x] End-to-end trial on a throwaway project (lead + 2 teammates), user watching the tabs.
   - Result 2026-10-25: lead started with `/lead` in its own tab, found its name, started the
     watcher, added Stories 3-4 and spawned teammate-m (manual mode) and teammate-s in parallel.
     teammate-s finished, wrapped up and was closed while teammate-m waited on permission prompts;
     both prompts reached the lead as events. Both teammates documented decisions and verification
     under their stories; the lead folded teammate sections into `## lead` in CHECKPOINT.md.
     Earlier component trial (this session as lead): DONE/QUESTION messages, answer by name,
     WRAPUP running the wrapup skill, close-teammate. Still to confirm by the user: the status line
     and the tabs closing themselves.
   - Known: a stopped teammate leaves its `~/.claude/sessions/<pid>.json`; Claude Code ignores it
     (dead PID) and it does not show in the session list.
   - Trial 2 result 2026-10-25 (calculator: teammate-a core module, teammate-b command line, both in
     `acceptEdits` mode, user ran `/wrapup` in the lead): verified the status line in both tabs
     (from `.agents/statusline/`), live `PermissionRequest` events naming the command, two teammates
     waiting on the user at once, teammate-b's division-by-zero question passed by the lead to the
     user and the answer relayed, teammates agreeing the interface directly, append-only change
     entries under each story, `/wrapup` in the lead wrapping up and closing both teammates first,
     and both teammate tabs closing by themselves (checked with UI Automation tab list). Final
     CHECKPOINT had only `## lead`; no AI mentions in project files.
   - Change 2026-10-25 (for verification): `statusline.ps1` now also saves its last line (no
     colours) to `.agents/statusline/<name>.txt`, and `run-teammate.ps1` records `consolePid`.
     Previously neither was saved. `consolePid` turned out to be the shared Windows Terminal
     process, so it cannot tell whether one tab closed; tab closing is checked by listing
     Windows Terminal tab titles with UI Automation instead.
   - Note: approvals the user makes with "always allow" in a teammate tab are saved by Claude Code
     to the project's `.claude/settings.local.json` (normal behaviour, not part of this skill).
7. [ ] Colour coding, no tab jump, teammates in the lead's permission mode (requested 2026-10-25).
   - Teammate colours: each teammate gets the first free colour of an 8-colour palette (`common.ps1`),
     used for its tab (`wt new-tab --tabColor`) and its name in the status line (true-colour ANSI).
     Stored as `color` in the teammate registry.
   - Lead colour: Windows Terminal has no supported way for a program to recolour an existing tab
     (no `wt` command, no escape sequence), and Claude Code hook `terminalSequence` only allows
     title/notification sequences. The user chose: a gold `LEAD` marker in the user's own
     status line (`~/.claude/statusline.ps1`), shown when `.agents/lead.json` names this session.
     Rejected: user colours the tab by hand, lead opening in a new gold tab, automating the tab
     colour menu with UI Automation (unsupported, fragile).
   - No tab jump: Windows Terminal always focuses a new tab and has no background option, so
     `spawn-teammate.ps1` reads the selected tab index (UI Automation, foreground Terminal window)
     and appends `; focus-tab -t <index>` to the same `wt` command.
   - Same mode: the lead skill registers a `PreToolUse` hook (`record-lead-mode.ps1`, matcher
     `PowerShell|Bash`) that writes the lead's `permission_mode` and session id to
     `.agents/lead.json` before each command. `spawn-teammate.ps1` uses it when `-PermissionMode`
     is not given (hooks report Manual as `default`, mapped to the CLI's `manual`); falls back to
     `auto`. Previously teammates always started in `auto` unless the lead passed a mode.
   - Verified: unit tests (mode mapping, colour pick, selected tab, status line, LEAD marker only
     for the lead's session id); live spawn from a session in auto mode kept the user on the same
     tab (index 2 before and after) and started the teammate in auto with colour #1E88E5.
     Live `/lead` in acceptEdits: the teammate was spawned in acceptEdits (mode inheritance works).
   - Change 2026-10-25 (found in test): the user saw no colour at all in lead and teammate tabs
     (status line and even the Claude Code logo white), while this session showed colour. Cause
     (verified): Claude Code runs its tool commands with `NO_COLOR=1` (plus `AI_AGENT`,
     `GIT_ASKPASS`, `GIT_EDITOR`, `GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE`, ...), and `wt new-tab`
     with a command line inherits the caller's environment by default, so every tab opened from a
     Claude command ran without colour. Previously `run-teammate.ps1` only removed the session
     identity variables (story 1 change entry). Now `spawn-teammate.ps1` opens the tab with
     `--reloadEnvironment` (fresh environment like a normally opened tab; tested: none of those
     variables reach the tab, and `claude` is on the saved user PATH), and `run-teammate.ps1` also
     removes `NO_COLOR` and the git/tool variables as a fallback.
   - Verified 2026-10-25: no tab jump confirmed by the user watching a live spawn (teammate-f), and
     by the selected tab index (2 before and after). Colour after the `--reloadEnvironment` fix:
     waiting for the user's check (gold LEAD, blue/green teammate tabs and names).
   - Verified 2026-10-25 (mode test in `lead-test-mode`): lead started in acceptEdits, recorded
     as acceptEdits, teammate-g spawned in acceptEdits; the user switched the lead to auto with
     Shift+Tab, the record changed to auto, teammate-h spawned in auto. teammate-g kept the mode it
     started with. (The earlier unexplained switch to auto in the teammate-d test was the user
     changing a tab's mode.)
8. [x] Linux version (tmux), built on the Linux machine 2026-10-26/27, recorded here 2026-10-27.
   - `scripts/*.sh` mirror the PowerShell scripts (jq for JSON); each teammate is a tmux window in
     the lead's tmux session, or in a detached session `lead-<project>` when the lead is not in
     tmux. Extras: `ssh-login.sh` (re-open and attach teammate windows on SSH login),
     `open-windows.sh`, `attach-loop.sh` (teammate moved into a Claude background session keeps its
     window), and `ssh-client/lead-ssh.ps1` + `tab-feed.sh` + `attach-tab.sh` (a Windows Terminal
     tab per teammate on the PC the user connects from over SSH).
   - Tested over SSH in rounds 1-4 (`lead-test-temporary` folder): spawn, DONE reports, wrap-up,
     close, two teammates in parallel. Not yet tested: a lead in a local (non-SSH) terminal.
   - Known: a lead started over SSH outside tmux ends when the SSH connection drops; the teammates
     keep running in tmux. Starting the lead inside tmux avoids it.
9. [ ] One skill folder for Windows and Linux, with installers (requested 2026-10-27).
   - Why: the two versions had drifted (the Linux-only wrap-up and spawn-again rules, the
     unpublished Windows `wrapup` copy). One folder means a shared fix is made once.
   - Clashing files and how they were merged: script names never clash (`.ps1` next to `.sh`).
     `SKILL.md`: shared procedure written once, platform specifics marked Windows / Linux.
     `teammate-role.md`: "tab" → "window". `README.md`: shared part plus Windows and Linux sections.
   - Hook and teammate settings: one command string for both. Checked in the Claude Code docs
     (hooks, status line): on Windows, hook and status line commands run through Git Bash when it
     is installed, otherwise PowerShell; there is a per-hook `shell` field. Git for Windows is
     therefore a requirement on Windows, and every command is
     `bash "$HOME/.claude/skills/lead/scripts/run-for-os.sh" <script> [args]`, which runs
     `<script>.ps1` under PowerShell when `$OSTYPE` is `msys`/`cygwin` and `<script>.sh` otherwise.
     This also removes the fixed `C:/Users/K.Badhan` paths.
   - `windows/` (SSH helpers for the PC) renamed `ssh-client/` so it is not mistaken for the
     Windows version.
   - Installers: `install.ps1` (winget installs Git for Windows and Windows Terminal if missing)
     and `install.sh` (apt/dnf/pacman/brew installs tmux and jq if missing); both warn when
     `claude` or the `wrapup` skill is missing, then copy the skill to `~/.claude/skills/lead`
     keeping its `state/`. `state/` added to `.gitignore`.
   - Verified on Linux 2026-10-27: `install.sh` installed over the old copy (result identical to
     the repo, `state/roots.txt` kept); `bash -n` on all `.sh`; SKILL.md frontmatter and
     `teammate-settings.json` parse. The exact hook, status line and notify-lead command strings run
     through `sh -c`: `.agents/lead.json` written with the mode, status line printed, event file
     written (`wants to use Bash: ls`). Live smoke test: teammate-i spawned in acceptEdits, wrote its
     file, its status line rendered through `run-for-os.sh`, closed with `close-teammate.sh` (window
     gone). Not yet tested: the hook firing inside a live `/lead` session, and anything on Windows
     (`install.ps1`, `run-for-os.sh` under Git Bash, a Windows lead with two teammates).

10. [ ] Teammate liveness survives PID reuse (found 2026-10-30).
   - Problem: `list-teammates`, `close-teammate` and `spawn-teammate` treated a teammate as alive when
     its recorded `hostPid` existed. A closed teammate's PID had been reused by the shell of the
     tmux "home" window, so the list showed it alive and `close-teammate` would have killed that
     shell.
   - Linux, done 2026-10-30: `run-teammate.sh` records `hostStart` (kernel start time,
     `/proc/<pid>/stat` field 22); `common.sh` `teammate_alive` needs the PID and that start time
     to match, and falls back to the record's `started` time (within 10 s) for older records;
     the three scripts use it. Verified: fake records against a live process (matching start:
     alive; wrong start, reused PID, dead PID: not alive), `close-teammate.sh` on the reused-PID
     record reported "not running" and left the process alone, `bash -n` on all changed
     scripts; the real stale record (teammate-smoke) now shows not alive.
   - Windows: not done. Instructions in `WINDOWS_PID_REUSE_FIX.txt`.
   - Also 2026-10-30: SKILL.md section 4 asks teammates that start a training run for the
     TensorBoard details (port, tunnel, link) and has the lead relay one combined list.

## Change log: role names (2026-10-31)
Previous approach: the skill was `/boss`; the main session was the "boss" and the task sessions
were "workers" (scripts `*-worker.*`, `notify-boss.*`, `record-boss-mode.*`, `.agents/boss.json`,
`.agents/workers/`, env `BOSS_TAB_ID`, tmux session `boss-<project>`, `boss-ssh.ps1`). The wording
implied hierarchy and made sessions act oddly.
Now: `/coordinator`; the main session is the coordinator (coordinates, communicates with the user,
steps in when a teammate asks) and the task sessions are teammates. All names above were renamed
accordingly (`*-teammate.*`, `notify-coordinator.*`, `.agents/coordinator.json`,
`.agents/teammates/`, `COORDINATOR_TAB_ID`, `coordinator-<project>`, `coordinator-ssh.ps1`).
Earlier entries above keep the renamed terms but describe the same history.

## Change log: coordinator also engineers (2026-10-31)
Previous approach (see the role-names entry above): the coordinator did no detailed work
("Protect your context. Do not do the detailed work yourself: no implementing, debugging or deep
code reading") and only coordinated and communicated.
Now: delegate by default, but the coordinator takes engineering work itself when a teammate is stuck
or asks, the work is small, it crosses teammates' areas (integration, final verification), a design
decision must be implemented consistently, or the user asks. Same documentation and verification
rules as a teammate apply.

## Change log: coordinator renamed to lead (2026-10-31)
Previous approach (entries above): the main session was called the "coordinator" (`/coordinator`,
`*-coordinator.*` scripts, `.agents/coordinator.json`, `COORDINATOR_TAB_ID`, tmux session
`coordinator-<project>`, `coordinator-ssh.ps1`, `{{COORDINATOR}}` in the teammate role). The name
undersold the role, which also takes on engineering work when needed.
Now: `/lead`; the main session is the lead and the task sessions are still teammates. Renamed
accordingly (`notify-lead.*`, `record-lead-mode.*`, `.agents/lead.json`, `LEAD_TAB_ID`,
`lead-<project>`, `lead-ssh.ps1`, `{{LEAD}}`). Entries above keep the old term as written then.

## Change log: repo renamed to lead-skill (2026-10-31)
Previous approach (entries above): the GitHub repo was `badhan-kv/boss-skill`, named after the
earlier "boss" skill name.
Now: `badhan-kv/lead-skill`, matching the skill name. The old URL redirects. README gained a
clone/upgrade note for users of the old `boss` install.
