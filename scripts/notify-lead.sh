#!/usr/bin/env bash
# Hook script (teammate sessions only): turns a permission prompt, dialog or API error into an
# event file the lead's watcher picks up. One file per event, so simultaneous events never collide.
# Usage: notify-lead.sh KIND   (hook JSON on stdin)
kind=${1:-event}
raw=$(cat)

root=${AGENT_ROOT:-$(jq -r '.cwd // empty' <<<"$raw" 2>/dev/null)}
[ -n "$root" ] || exit 0
name=${AGENT_NAME:-unknown-teammate}

type=$(jq -r '[.notification_type, .error_type, .matcher, .reason] | map(select(. != null and . != "")) | first // ""' <<<"$raw" 2>/dev/null)
msg=$(jq -r '[.message, .error, .error_message, .title] | map(select(. != null and . != "")) | first // ""' <<<"$raw" 2>/dev/null)

# PermissionRequest: say exactly what is waiting for approval.
if [ "$(jq -r '.hook_event_name // empty' <<<"$raw" 2>/dev/null)" = PermissionRequest ]; then
    type=permission
    msg=$(jq -r '
      (.tool_input // {}) as $ti
      | ([$ti.command, $ti.file_path, $ti.url, $ti.path, $ti.pattern] | map(select(. != null and . != "")) | first
         // ($ti | tojson)) as $d
      | ($d | tostring | gsub("\\s+"; " ")) as $d
      | "wants to use \(.tool_name): \(if ($d | length) > 200 then $d[0:200] + "..." else $d end)"' <<<"$raw")
fi
# Print nothing: this hook only observes and must not answer the permission request.

dir="$root/.agents/events"
mkdir -p "$dir"
file="$dir/$(date +%Y%m%d-%H%M%S-%3N)-$name-$kind-$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n').json"
jq -n --arg time "$(date +%Y-%m-%dT%H:%M:%S)" --arg teammate "$name" --arg kind "$kind" \
    --arg type "$type" --arg message "$msg" \
    '{time:$time, teammate:$teammate, kind:$kind, type:$type, message:$message}' > "$file.tmp" \
    && mv "$file.tmp" "$file"
exit 0
