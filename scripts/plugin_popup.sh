#!/usr/bin/env bash
# Wrapper script to handle popup mode based on tmux options
# Called from tpm key bindings

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/variables.sh"

# Get tmux option helper
get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value="$(tmux show-option -gqv "$option" 2>/dev/null)"
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

# Parse mode argument
mode=""
if [ "$1" = "--update" ]; then
	mode="--update"
fi

# Read popup options
popup_enabled="$(get_tmux_option "$popup_option" "$default_popup")"

# Check if popup should be used
if [ "$popup_enabled" = "on" ] && command -v fzf &>/dev/null; then
	popup_width="$(get_tmux_option "$popup_width_option" "$default_popup_width")"
	popup_height="$(get_tmux_option "$popup_height_option" "$default_popup_height")"
	title="TPM"
	[ "$mode" = "--update" ] && title="TPM - Update"

	# Run in popup
	tmux display-popup -E -w "$popup_width" -h "$popup_height" -T "$title" \
		"cd '$CURRENT_DIR' && bash plugin_list.sh $mode"
else
	# Run directly (legacy mode)
	if [ "$popup_enabled" != "on" ]; then
		tmux display-message "Popup disabled, running legacy mode..."
	else
		tmux display-message "fzf not found, running legacy mode..."
	fi

	if [ "$mode" = "--update" ]; then
		bash "$CURRENT_DIR/update_plugin.sh" all
	else
		bash "$CURRENT_DIR/install_plugins.sh" --tmux-echo
	fi
fi

# Reload tmux environment after action completes
conf_file=$(tmux show-env -g TMUX_CONF_LOCAL 2>/dev/null | cut -d= -f2-)
if [ -n "$conf_file" ]; then
	tmux source-file "$conf_file" >/dev/null 2>&1
else
	tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1
fi
