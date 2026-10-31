#!/usr/bin/env bash
# Reopen a tmux window for every running teammate that has none (e.g. after it was moved into a
# Claude background session, or after the tmux server ended), then optionally attach.
# Usage: open-windows.sh [--root DIR] [--attach]
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

root=$PWD attach=
while [ $# -gt 0 ]; do
    case $1 in
        --root) root=$2; shift 2 ;;
        --attach) attach=1; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done
root=$(cd "$root" && pwd) || exit 1
command -v tmux >/dev/null || { echo "tmux is required" >&2; exit 1; }
sess=$(lead_tmux_session "$root")

shopt -s nullglob
opened=0
for f in "$root"/.agents/teammates/*.json; do
    name=$(jq -r .name "$f")
    win=$(jq -r '.tmuxWindow // empty' "$f")
    # Its window is still open: nothing to do.
    if [ -n "$win" ] && tmux list-windows -a -F '#{window_id}' 2>/dev/null | grep -qxF "$win"; then
        continue
    fi
    bg=$(bg_session_id "$root" "$name") || continue
    tmux has-session -t "=$sess" 2>/dev/null || tmux new-session -d -s "$sess" -n home -c "$root"
    color=$(jq -r '.color // "#1E88E5"' "$f")
    wid=$(tmux new-window -d -P -F '#{window_id}' -t "=$sess:" -n "$name" -c "$root" \
        "bash $(printf '%q' "$SKILL_DIR/scripts/attach-loop.sh") $(printf '%q' "$root") $(printf '%q' "$name")")
    tmux set-window-option -t "$wid" automatic-rename off >/dev/null
    tmux set-window-option -t "$wid" window-status-style "fg=$color,bold" >/dev/null
    tmux set-window-option -t "$wid" window-status-current-style "fg=black,bg=$color,bold" >/dev/null
    set_teammate "$root" "$name" '.status="background" | .bgId=$id | .tmuxSession=$s | .tmuxWindow=$w | .hostPid=null' \
        --arg id "$bg" --arg s "$sess" --arg w "$wid"
    request_remote_tab "$sess" "$wid" "$name"
    echo "Opened window for '$name' (background session $bg) in tmux session $sess."
    opened=$((opened + 1))
done

if [ -n "$attach" ] && tmux has-session -t "=$sess" 2>/dev/null; then
    [ -t 0 ] && [ -t 1 ] && [ -z "${TMUX:-}" ] && exec tmux attach -t "=$sess"
fi
[ "$opened" -gt 0 ] || [ -n "$attach" ] || echo "No teammate windows needed opening."
