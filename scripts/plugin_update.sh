#!/usr/bin/env bash
# Script to update a plugin

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$CURRENT_DIR")/lib"

source "$LIB_DIR/plugin_functions.sh"
source "$LIB_DIR/utility.sh"

# Get plugin info from first argument (passed from fzf selection)
# The selection format is: "[status]  plugin_name"
plugin_line="$1"

# Extract plugin name - remove status prefix like "[installed]  "
plugin_name=$(echo "$plugin_line" | sed 's/^\[.*\][[:space:]]*//')

if [ -z "$plugin_name" ]; then
	echo "Error: No plugin name provided" >&2
	exit 1
fi

# Update the plugin by pulling latest changes
plugin_path="$(plugin_path_helper "$plugin_name")"

if [ -d "$plugin_path" ]; then
	echo "Updating $plugin_name..."
	cd "$plugin_path" && GIT_TERMINAL_PROMPT=0 git pull --ff-only 2>&1
	
	if [ $? -eq 0 ]; then
		echo "Successfully updated $plugin_name"
	else
		echo "Failed to update $plugin_name" >&2
		exit 1
	fi
else
	echo "Error: Plugin $plugin_name not found at $plugin_path" >&2
	exit 1
fi
