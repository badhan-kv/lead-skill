#!/usr/bin/env bash
# Runs the lead script NAME for this OS: scripts/NAME.ps1 under PowerShell on Windows (where Claude
# Code runs hook and status line commands through Git Bash), scripts/NAME.sh under bash elsewhere.
# Lets SKILL.md's hook and teammate-settings.json use one command string on both. stdin passes through.
# Usage: run-for-os.sh NAME [ARGS...]
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
name=$1; shift
case "$OSTYPE" in
    msys*|cygwin*)
        exec powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$dir/$name.ps1")" "$@" ;;
    *)
        exec bash "$dir/$name.sh" "$@" ;;
esac
