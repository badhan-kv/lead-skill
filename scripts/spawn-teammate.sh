#!/usr/bin/env bash
# Open a teammate session in a new tmux window.
# The brief must already exist at <root>/.agents/briefs/<name>.md.
# Usage: spawn-teammate.sh --name N --task T --lead B [--root DIR] [--permission-mode M] [--model X]
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

name= task= lead= root=$PWD mode= model=
while [ $# -gt 0 ]; do
    case $1 in
        --name) name=$2; shift 2 ;;
        --task) task=$2; shift 2 ;;
        --lead) lead=$2; shift 2 ;;
        --root) root=$2; shift 2 ;;
        --permission-mode) mode=$2; shift 2 ;;
        --model) model=$2; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$name" ] && [ -n "$task" ] && [ -n "$lead" ] || { echo "Need --name, --task and --lead" >&2; exit 2; }
[[ $name =~ ^[a-z0-9][a-z0-9-]{0,39}$ ]] || { echo "Teammate name must be lowercase letters, digits and hyphens (max 40), e.g. teammate-api" >&2; exit 2; }
case "$mode" in ''|auto|acceptEdits|manual|plan|dontAsk|bypassPermissions) ;; *) echo "Bad permission mode: $mode" >&2; exit 2 ;; esac

root=$(cd "$root" && pwd)
brief="$root/.agents/briefs/$name.md"
[ -f "$brief" ] || { echo "Brief not found: $brief (write it before spawning)" >&2; exit 1; }
command -v tmux >/dev/null || { echo "tmux is required" >&2; exit 1; }

if existing=$(read_teammate "$root" "$name"); then
    if [ "$(jq -r .status <<<"$existing")" = running ] && teammate_alive "$existing"; then
        echo "Teammate '$name' is already running (host PID $(jq -r .hostPid <<<"$existing"))" >&2; exit 1
    fi
fi

[ -n "$mode" ] || mode=$(lead_permission_mode "$root")
[ -n "$mode" ] || mode=auto
color=$(free_teammate_color "$root")

mkdir -p "$root/.agents/events" "$root/.agents/tasks"
printf '%s\n' "$task" > "$root/.agents/tasks/$name.txt"
ensure_agents_ignored "$root"
remember_root "$root"

save_teammate "$root" "$name" "$(jq -n --arg name "$name" --arg task "$task" --arg lead "$lead" \
    --arg root "$root" --arg mode "$mode" --arg color "$color" --arg model "$model" \
    --arg created "$(date +%Y-%m-%dT%H:%M:%S)" \
    '{name:$name, task:$task, lead:$lead, root:$root, permissionMode:$mode, color:$color,
      model:$model, status:"starting", hostPid:null, created:$created}')"

# Where to put the window: the lead's own tmux session if it runs in one, else a detached
# session "lead-<project>" the user can attach to.
if [ -n "${TMUX:-}" ]; then
    sess=$(tmux display-message -p '#S')
    attach_hint="Windows are in your current tmux session ($sess)."
else
    sess=$(lead_tmux_session "$root")
    tmux has-session -t "=$sess" 2>/dev/null || tmux new-session -d -s "$sess" -n home -c "$root"
    attach_hint="Attach with: tmux attach -t $sess   (switch windows: Ctrl-b n / p / w)"
    [ -n "${LEAD_TAB_ID:-}" ] && attach_hint+=$'\n'"Over SSH, lead-ssh.ps1 on the PC opens a terminal tab for it."
fi

runner="$SKILL_DIR/scripts/run-teammate.sh"
# -d: do not switch the user away from the window they are on.
wid=$(tmux new-window -d -P -F '#{window_id}' -t "=$sess:" -n "$name" -c "$root" \
    "bash $(printf '%q' "$runner") $(printf '%q' "$name")")
tmux set-window-option -t "$wid" automatic-rename off >/dev/null
tmux set-window-option -t "$wid" window-status-style "fg=$color,bold" >/dev/null
tmux set-window-option -t "$wid" window-status-current-style "fg=black,bg=$color,bold" >/dev/null
set_teammate "$root" "$name" '.tmuxSession=$s | .tmuxWindow=$w' --arg s "$sess" --arg w "$wid"
request_remote_tab "$sess" "$wid" "$name"

# Wait for the window to start and register its PID.
for _ in $(seq 1 40); do
    sleep 0.5
    status=$(read_teammate "$root" "$name" | jq -r .status)
    [ "$status" = starting ] || break
done
if [ "$status" = running ]; then
    echo "Spawned teammate '$name' (host PID $(read_teammate "$root" "$name" | jq -r .hostPid)) in tmux window $sess:$name: mode $mode, colour $color."
    echo "$attach_hint"
else
    echo "WARNING: teammate '$name' did not report running within 20s (status: $status). Check tmux session $sess."
fi
