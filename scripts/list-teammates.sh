#!/usr/bin/env bash
# Lead: list registered teammates with their task and whether their process is still alive.
# Usage: list-teammates.sh [--root DIR]
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
root=$PWD
[ "${1:-}" = --root ] && root=$2

shopt -s nullglob
files=("$root"/.agents/teammates/*.json)
[ ${#files[@]} -gt 0 ] || { echo 'No teammates registered.'; exit 0; }
printf '%-24s %-10s %-6s %s\n' NAME STATUS ALIVE TASK
for f in "${files[@]}"; do
    teammate_alive "$(<"$f")" && alive=yes || alive=no
    printf '%-24s %-10s %-6s %s\n' "$(jq -r .name "$f")" "$(jq -r .status "$f")" "$alive" "$(jq -r .task "$f")"
done
