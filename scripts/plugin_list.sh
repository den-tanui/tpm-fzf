#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$CURRENT_DIR")/lib"

source "$LIB_DIR/plugin_functions.sh"
source "$LIB_DIR/utility.sh"
source "$CURRENT_DIR/variables.sh"

# Get tmux option helper (same as in tpm)
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

# Check if we should run in popup mode
should_use_popup() {
	local popup_enabled="$(get_tmux_option "$popup_option" "$default_popup")"
	[ "$popup_enabled" = "on" ] && command -v fzf &>/dev/null
}

# Run in popup or legacy mode based on tmux options
run_with_popup() {
	local mode="$1" # "" for install, "--update" for update

	if should_use_popup; then
		local popup_width="$(get_tmux_option "$popup_width_option" "$default_popup_width")"
		local popup_height="$(get_tmux_option "$popup_height_option" "$default_popup_height")"
		local title="TPM"
		[ "$mode" = "--update" ] && title="TPM - Update"

		tmux display-popup -E -w "$popup_width" -h "$popup_height" -T "$title" \
			"cd '$CURRENT_DIR' && bash plugin_list.sh $mode"
	else
		# Legacy mode - run directly
		if [ "$mode" = "--update" ]; then
			bash update_plugin.sh all
		else
			bash install_plugins.sh --tmux-echo
		fi
	fi

	# Reload tmux environment after action completes
	local conf_file
	conf_file=$(tmux show-env -g TMUX_CONF_LOCAL 2>/dev/null | cut -d= -f2-)
	if [ -n "$conf_file" ]; then
		tmux source-file "$conf_file" >/dev/null 2>&1
	else
		tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1
	fi
}

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

check_fzf() {
	if ! command -v fzf &>/dev/null; then
		echo -e "${RED}Error: fzf is not installed${RESET}" >&2
		echo "Install: https://github.com/junegunn/fzf" >&2
		exit 1
	fi
}

auto_install_pending() {
	local plugins plugin
	plugins="$(tpm_plugins_list_helper)"
	for plugin in $plugins; do
		if ! plugin_already_installed "$plugin"; then
			local plugin_name="$(plugin_name_helper "$plugin")"
			echo -e "${YELLOW}Installing:${RESET} $plugin_name"
			cd "$(tpm_path)" && GIT_TERMINAL_PROMPT=0 git clone --single-branch --recursive "$plugin" >/dev/null 2>&1
		fi
	done
}

generate_plugin_list() {
	categorize_plugins | while IFS='|' read -r status name path; do
		case "$status" in
		pending)
			echo -e "${YELLOW}[pending]${RESET}  ${CYAN}${name}${RESET}"
			;;
		installed)
			echo -e "${GREEN}[installed]${RESET} ${BOLD}${name}${RESET}"
			;;
		orphaned)
			echo -e "${RED}[orphaned]${RESET}  ${DIM}${name}${RESET}"
			;;
		esac
	done
	# Also output available plugins
	generate_available_list
}

# Generate list of available plugins from TPM repository
generate_available_list() {
	local available_plugins
	available_plugins=$(filter_available_plugins 2>/dev/null)

	if [ -z "$available_plugins" ]; then
		return
	fi

	# Output available plugins
	echo "$available_plugins" | while IFS='|' read -r name url desc; do
		[ -z "$name" ] && continue
		echo -e "${BLUE}[available]${RESET} ${CYAN}${name}${RESET}"
	done
}

main() {
	if [ "$1" = "--list" ]; then
		generate_plugin_list
		return
	fi
	if [ "$1" = "--update" ]; then
		check_fzf
		auto_install_pending

		# Show header for update mode
		echo -e ""
		echo -e "${GREEN}Update mode${RESET} - select plugins to update"
		echo -e ""

		local selection
		selection=$(generate_plugin_list |
			fzf --ansi \
				--multi \
				--preview="$CURRENT_DIR/plugin_preview.sh {}" \
				--preview-window="right:70%:wrap" \
				--prompt="Update> " \
				--footer="Alt+S=source | Alt+I=install | Alt+U=update all | Alt+C=clean | Alt+D=delete | Tab=select" \
				--bind="alt-u:execute($CURRENT_DIR/../bin/update_plugins all && $CURRENT_DIR/plugin_reload.sh)+reload($CURRENT_DIR/plugin_list.sh --list)" \
				--bind="alt-s:execute($CURRENT_DIR/plugin_source.sh && $CURRENT_DIR/plugin_reload.sh)" \
				--bind="alt-i:execute($CURRENT_DIR/plugin_install_selected.sh {} && $CURRENT_DIR/plugin_reload.sh)" \
				--bind="alt-c:execute($CURRENT_DIR/../bin/clean_plugins && $CURRENT_DIR/plugin_reload.sh)" \
				--bind="alt-d:execute($CURRENT_DIR/plugin_delete.sh {} && $CURRENT_DIR/plugin_reload.sh)+reload($CURRENT_DIR/plugin_list.sh --list)")

		if [ -n "$selection" ]; then
			echo ""
			echo -e "${BOLD}Updated:${RESET}"
			echo "$selection"
		fi
		return
	fi
	check_fzf
	auto_install_pending

	# Show header with legend
	echo -e ""
	echo -e "${YELLOW}pending${RESET}   = new plugin (will be installed)"
	echo -e "${GREEN}installed${RESET} = working plugin"
	echo -e "${RED}orphaned${RESET}  = cleanup needed"
	echo -e "${BLUE}available${RESET} = from TPM repository"
	echo -e ""

	local selection
	selection=$(generate_plugin_list |
		fzf --ansi \
			--multi \
			--preview="$CURRENT_DIR/plugin_preview.sh {}" \
			--preview-window="right:70%:wrap" \
			--border-label "Plugins" \
			--header="Alt+R=refresh | Alt+S=source | Alt+I=install | Alt+U=update | Alt+C=clean | Tab=select | Enter=confirm | Alt+D=delete" \
			--bind="alt-r:execute($CURRENT_DIR/refresh_available.sh)+reload($CURRENT_DIR/plugin_list.sh --list)" \
			--bind="alt-d:execute($CURRENT_DIR/plugin_delete.sh {} && $CURRENT_DIR/plugin_reload.sh)+reload($CURRENT_DIR/plugin_list.sh --list)" \
			--bind="alt-s:execute($CURRENT_DIR/plugin_source.sh && $CURRENT_DIR/plugin_reload.sh)" \
			--bind="alt-i:execute($CURRENT_DIR/plugin_install_selected.sh {} && $CURRENT_DIR/plugin_reload.sh)" \
			--bind="alt-u:execute($CURRENT_DIR/plugin_update.sh {} && $CURRENT_DIR/plugin_reload.sh)+reload($CURRENT_DIR/plugin_list.sh --list)" \
			--bind="alt-c:execute($CURRENT_DIR/../bin/clean_plugins && $CURRENT_DIR/plugin_reload.sh)")

	if [ -n "$selection" ]; then
		echo ""
		echo -e "${BOLD}Selected:${RESET}"
		echo "$selection"
	fi
}

main "$@"
