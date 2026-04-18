#!/usr/bin/env bash
# Helper script to reload tmux after actions

# Reload tmux environment
reload_tmux() {
	local conf_file
	conf_file=$(tmux show-env -g TMUX_CONF_LOCAL 2>/dev/null | cut -d= -f2-)
	if [ -n "$conf_file" ] && [ -f "$conf_file" ]; then
		tmux source-file "$conf_file" >/dev/null 2>&1
	else
		tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1
	fi
}

reload_tmux
echo "Tmux environment reloaded"
