#!/usr/bin/env bash
# Hook (registered by the lead skill, PreToolUse): records the lead's current permission mode so
# spawn-teammate.sh can start teammates in the same mode. Prints nothing and never blocks the tool.
{
    raw=$(cat)
    mode=$(jq -r '.permission_mode // empty' <<<"$raw")
    cwd=$(jq -r '.cwd // empty' <<<"$raw")
    [ -n "$mode" ] && [ -n "$cwd" ] || exit 0
    mkdir -p "$cwd/.agents"
    jq -n --arg sid "$(jq -r '.session_id // empty' <<<"$raw")" --arg mode "$mode" \
        --arg t "$(date +%Y-%m-%dT%H:%M:%S)" \
        '{sessionId:$sid, permissionMode:$mode, updated:$t}' > "$cwd/.agents/lead.json"
} 2>/dev/null
exit 0
