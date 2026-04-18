#!/usr/bin/env bash
# Script to update a plugin (calls update_plugin.sh with extracted name)

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get plugin info from first argument (passed from fzf selection)
# The selection format is: "[status]  plugin_name"
plugin_line="$1"

# Extract plugin name - remove status prefix like "[installed]  "
plugin_name=$(echo "$plugin_line" | sed 's/^\[.*\][[:space:]]*//')

if [ -z "$plugin_name" ]; then
	echo "Error: No plugin name provided" >&2
	exit 1
fi

# Call update_plugin.sh with just the plugin name
cd "$CURRENT_DIR" && bash update_plugin.sh "$plugin_name"
