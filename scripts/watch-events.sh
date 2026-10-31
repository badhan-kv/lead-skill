#!/usr/bin/env bash
# Lead: background watcher (run under the Monitor tool). Prints one line per teammate event and
# moves the event file to events/seen. Events written while no watcher runs are kept and
# reported on the next start.
# Usage: watch-events.sh [--root DIR]
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
root=$PWD
[ "${1:-}" = --root ] && root=$2

events="$root/.agents/events"
seen="$events/seen"
mkdir -p "$seen"

while true; do
    for f in $(ls -1 "$events"/*.json 2>/dev/null | sort); do
        # The hook may still be writing it; try again next round.
        line=$(jq -r '"[teammate event] \(.teammate) | \(.kind)\(if .type != "" and .type != null then "/" + .type else "" end) | \(.message)"' "$f" 2>/dev/null) || continue
        printf '%s\n' "$line"
        mv -f "$f" "$seen/"
    done
    sleep 1
done
