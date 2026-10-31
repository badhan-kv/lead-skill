#!/usr/bin/env bash
# Installs the lead skill on Linux (or macOS): installs missing requirements (tmux, jq) with the
# system package manager, checks for claude and the wrapup skill, then copies this folder to
# ~/.claude/skills/lead, keeping the runtime state/ already there.
# Usage: bash install.sh
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="$HOME/.claude/skills/lead"

missing=()
for c in tmux jq; do command -v "$c" >/dev/null || missing+=("$c"); done
if [ ${#missing[@]} -gt 0 ]; then
    echo "Installing: ${missing[*]}"
    if command -v apt-get >/dev/null; then sudo apt-get update -qq && sudo apt-get install -y "${missing[@]}"
    elif command -v dnf >/dev/null; then sudo dnf install -y "${missing[@]}"
    elif command -v pacman >/dev/null; then sudo pacman -S --needed --noconfirm "${missing[@]}"
    elif command -v brew >/dev/null; then brew install "${missing[@]}"
    else echo "Install ${missing[*]} with your package manager, then run this again." >&2; exit 1
    fi
fi
command -v claude >/dev/null || echo "Warning: 'claude' is not on PATH; teammates need it."
[ -f "$HOME/.claude/skills/wrapup/SKILL.md" ] \
    || echo "Warning: no wrapup skill at ~/.claude/skills/wrapup; teammate wrap-up reads it."

if [ "$src" != "$dest" ]; then
    mkdir -p "$dest"
    tar -C "$src" --exclude=./.git --exclude=./state -cf - . | tar -C "$dest" -xf -
fi
chmod +x "$dest"/scripts/*.sh
echo "Installed to $dest"
echo "Optional, SSH auto-attach: add to ~/.bashrc:"
echo "  [ -f \"\$HOME/.claude/skills/lead/scripts/ssh-login.sh\" ] && . \"\$HOME/.claude/skills/lead/scripts/ssh-login.sh\""
