# Sourced from ~/.bashrc. On an interactive SSH login outside tmux, reopen teammate windows for
# every project that has running teammates and attach to the first such tmux session.
# Ctrl-b d detaches back to the login shell. Set LEAD_AUTO_ATTACH=0 to turn it off.
if [[ $- == *i* ]] && [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ] && [ -t 0 ] && [ -t 1 ] \
    && [ "${LEAD_AUTO_ATTACH:-1}" != 0 ] && command -v tmux >/dev/null && command -v jq >/dev/null; then
    _lead_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [ -s "$_lead_dir/state/roots.txt" ]; then
        _lead_target=
        while IFS= read -r _lead_root; do
            [ -d "$_lead_root/.agents/teammates" ] || continue
            bash "$_lead_dir/scripts/open-windows.sh" --root "$_lead_root" >/dev/null 2>&1
            _lead_sess="lead-$(basename "$_lead_root" | tr -c "A-Za-z0-9_\n-" "_" | tr -d "\n")"
            # Attach only when the session has a teammate window besides "home".
            if [ -z "$_lead_target" ] && [ "$(tmux list-windows -t "=$_lead_sess" -F '#W' 2>/dev/null \
                | grep -cvx home)" -gt 0 ]; then
                _lead_target=$_lead_sess
            fi
        done < "$_lead_dir/state/roots.txt"
        [ -n "$_lead_target" ] && tmux attach -t "=$_lead_target"
    fi
    unset _lead_dir _lead_root _lead_sess _lead_target
fi
