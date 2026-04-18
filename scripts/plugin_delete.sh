#!/usr/bin/env bash
# Script to delete a plugin - either from tmux.conf (if installed) or from disk (if orphaned)

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$CURRENT_DIR")/lib"

source "$LIB_DIR/plugin_functions.sh"
source "$LIB_DIR/utility.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Get plugin info from first argument (passed from fzf selection)
# The selection format is: "[status]  plugin_name"
plugin_line="$1"

# Extract status (e.g., "orphaned", "installed")
status=$(echo "$plugin_line" | sed -E 's/^\[([^]]+)\].*/\1/')

# Extract plugin name - remove status prefix like "[orphaned]  "
plugin_name=$(echo "$plugin_line" | sed 's/^\[.*\][[:space:]]*//')

if [ -z "$plugin_name" ]; then
	echo -e "${RED}Error: No plugin name provided${RESET}" >&2
	exit 1
fi

case "$status" in
orphaned)
	# Delete the plugin directory from disk
	plugin_path="$(tpm_path)${plugin_name}/"
	if [ -d "$plugin_path" ]; then
		rm -rf "$plugin_path"
		if [ -d "$plugin_path" ]; then
			echo -e "${RED}Failed to remove:${RESET} $plugin_path" >&2
			exit 1
		else
			echo -e "${GREEN}Deleted:${RESET} $plugin_name (directory removed)"
			exit 0
		fi
	else
		echo -e "${YELLOW}Not found:${RESET} $plugin_path" >&2
		exit 1
	fi
	;;
installed)
	# Comment out the @plugin line in tmux.conf
	tmux_conf=$(_get_user_tmux_conf)

	if [ ! -f "$tmux_conf" ]; then
		echo -e "${RED}Error: tmux.conf not found at $tmux_conf${RESET}" >&2
		exit 1
	fi

	# Check if the line exists and is not already commented
	if grep -qE "^[ ]*set[ ]+-g[ ]+@plugin[ ]+['\"]?${plugin_name}['\"]?" "$tmux_conf"; then
		# Comment out the line (prepend #)
		sed -i.bak -E "s|(^[ ]*set[ ]+-g[ ]+@plugin[ ]+['\"]?${plugin_name}['\"]?)|# \1|" "$tmux_conf"
		echo -e "${GREEN}Commented out:${RESET} $plugin_name in $tmux_conf"
		echo -e "${YELLOW}Run 'tmux source-file $tmux_conf' to apply changes${RESET}"
		exit 0
	else
		# Try as partial match (for org/repo format)
		if grep -qE "#[ ]*set[ ]+-g[ ]+@plugin.*${plugin_name}" "$tmux_conf"; then
			echo -e "${YELLOW}Already commented:${RESET} $plugin_name"
			exit 0
		else
			echo -e "${RED}Plugin not found in tmux.conf:${RESET} $plugin_name" >&2
			exit 1
		fi
	fi
	;;
*)
	echo -e "${RED}Unknown status:${RESET} $status" >&2
	exit 1
	;;
esac
