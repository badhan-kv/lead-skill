#!/usr/bin/env bash
# Status line for teammate sessions: the machine's normal status line (LINUX (SSH) tag, host, cwd,
# model) followed by teammate name | task | context used.
input=$(cat)

# Machine-wide base line, unchanged.
base=""
[ -f "$HOME/.claude/statusline.sh" ] && base=$(printf '%s' "$input" | bash "$HOME/.claude/statusline.sh")

name=${AGENT_NAME:-$(jq -r '.session_name // empty' <<<"$input")}
name=${name:-teammate}

task="" color='1;36'
if [ -n "${AGENT_ROOT:-}" ]; then
    tf="$AGENT_ROOT/.agents/tasks/$name.txt"
    wf="$AGENT_ROOT/.agents/teammates/$name.json"
    [ -f "$tf" ] && task=$(head -n1 "$tf")
    if [ -f "$wf" ]; then
        [ -z "$task" ] && task=$(jq -r '.task // empty' "$wf")
        hex=$(jq -r '.color // empty' "$wf")
        if [[ $hex =~ ^#[0-9A-Fa-f]{6}$ ]]; then
            color=$(printf '1;38;2;%d;%d;%d' 0x${hex:1:2} 0x${hex:3:2} 0x${hex:5:2})
        fi
    fi
fi

ctx=$(jq -r 'if .context_window.used_percentage != null then " | ctx \(.context_window.used_percentage | round)%" else "" end' <<<"$input")

line=$(printf '\033[%sm%s\033[0m' "$color" "$name")
[ -n "$task" ] && line+=" | $task"
line+="$ctx"

printf '%s | %s\n' "$base" "$line"

# Keep the last shown line (without colours) so the lead can see what each window displays.
if [ -n "${AGENT_ROOT:-}" ] && [ -n "${AGENT_NAME:-}" ]; then
    mkdir -p "$AGENT_ROOT/.agents/statusline" 2>/dev/null &&
        printf '%s | %s\n' "$base" "$line" | sed 's/\x1b\[[0-9;]*m//g' > "$AGENT_ROOT/.agents/statusline/$name.txt"
fi
