#!/usr/bin/env bash
# Runs over SSH from lead-ssh.ps1 on the PC the user connects from. Prints one line
# "SESSION<TAB>WINDOW_ID<TAB>NAME" per teammate window that needs a terminal tab there: first the
# teammate windows already open, then each one spawned later from the SSH session started with the
# same LEAD_TAB_ID.
# Usage: tab-feed.sh TAB_ID
# An empty line every 20s ends this script once the SSH connection is gone.
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
client=${1:?Usage: tab-feed.sh TAB_ID}
mkdir -p "$TAB_REQ_DIR"
declare -A sent

window_open() { tmux list-windows -a -F '#{window_id}' 2>/dev/null | grep -qxF "$1"; }
emit() {
    [ -n "${sent[$2]:-}" ] && return 0
    window_open "$2" || return 0
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" || exit 0
    sent[$2]=1
}

# Reopen windows for background teammates, then send every open teammate window.
if [ -s "$ROOTS_FILE" ]; then
    while IFS= read -r root; do
        [ -d "$root/.agents/teammates" ] || continue
        bash "$SKILL_DIR/scripts/open-windows.sh" --root "$root" >/dev/null 2>&1
        for f in "$root"/.agents/teammates/*.json; do
            [ -f "$f" ] || continue
            IFS=$'\t' read -r st sess wid name < <(jq -r '[.status, .tmuxSession // "", .tmuxWindow // "", .name] | @tsv' "$f")
            [ "$st" != closed ] && [ "$sess" = "$(lead_tmux_session "$root")" ] && emit "$sess" "$wid" "$name"
        done
    done < "$ROOTS_FILE"
fi

beat=0
while true; do
    for f in "$TAB_REQ_DIR"/*; do
        case $f in *.tmp|*'/*') continue ;; esac
        IFS=$'\t' read -r c sess wid name < "$f" || { rm -f "$f"; continue; }
        if [ "$c" = "$client" ]; then
            rm -f "$f"
            emit "$sess" "$wid" "$name"
        elif [ $(( $(date +%s) - $(stat -c %Y "$f") )) -gt 300 ]; then
            rm -f "$f"   # no feed with that id picked it up
        fi
    done
    sleep 1
    beat=$((beat + 1))
    [ $((beat % 20)) -eq 0 ] && { printf '\n' || exit 0; }
done
