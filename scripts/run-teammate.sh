#!/usr/bin/env bash
# Runs inside the teammate's tmux window: sets the teammate environment and starts claude.
# When claude exits (or close-teammate.sh stops it) this script exits and the window closes.
# Usage: run-teammate.sh NAME   (cwd = project root)
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

name=$1
root=$PWD
w=$(read_teammate "$root" "$name") || { echo "No teammate '$name' registered under $root"; read -r -p 'Press Enter to close'; exit 1; }

# Drop what must not carry over from the lead's command environment: its session identity (so this
# claude registers as its own session and cannot see the lead's messaging token), NO_COLOR (turns
# all colour off) and the non-interactive git/tool settings.
unset CLAUDECODE CLAUDE_PID CLAUDE_CODE_SESSION_ID CLAUDE_CODE_CHILD_SESSION \
      CLAUDE_CODE_BRIDGE_SESSION_ID CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ATTENDED \
      CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN NO_COLOR AI_AGENT \
      GIT_ASKPASS GIT_EDITOR GIT_TERMINAL_PROMPT GCM_INTERACTIVE COREPACK_ENABLE_AUTO_PIN

lead=$(jq -r .lead <<<"$w")
mode=$(jq -r .permissionMode <<<"$w")
model=$(jq -r '.model // empty' <<<"$w")

export AGENT_NAME=$name AGENT_LEAD=$lead AGENT_ROOT=$root AGENT_SKILL_DIR=$SKILL_DIR
printf '\033]2;%s\007' "$name"

set_teammate "$root" "$name" '.status="running" | .hostPid=$pid | .hostStart=$st | .started=$t' \
    --argjson pid $$ --arg st "$(pid_start $$)" --arg t "$(date +%Y-%m-%dT%H:%M:%S)"

role=$(<"$SKILL_DIR/teammate-role.md")
role=${role//\{\{NAME\}\}/$name}
role=${role//\{\{LEAD\}\}/$lead}
prompt="You are teammate '$name'. Your lead session is '$lead'. Read your brief at .agents/briefs/$name.md and start."

args=(--name "$name" --settings "$SKILL_DIR/teammate-settings.json"
      --append-system-prompt "$role" --permission-mode "$mode")
[ -n "$model" ] && args+=(--model "$model")
args+=("$prompt")

claude "${args[@]}"
code=$?

# If the session was moved into a Claude background session, keep this window: attach to it
# until it ends, so the user still finds the teammate here.
sleep 2
if bg_session_id "$root" "$name" >/dev/null; then
    exec bash "$SKILL_DIR/scripts/attach-loop.sh" "$root" "$name"
fi

set_teammate "$root" "$name" '.status="closed" | .ended=$t | .exitCode=$c' \
    --arg t "$(date +%Y-%m-%dT%H:%M:%S)" --argjson c "$code"
exit 0
