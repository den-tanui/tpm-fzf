#!/usr/bin/env bash
# Script to install selected plugin from fzf selection

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$CURRENT_DIR")/lib"

source "$LIB_DIR/plugin_functions.sh"
source "$LIB_DIR/utility.sh"

# Insert plugin between TPM markers, creating them if needed
insert_plugin_between_markers() {
	local tmux_conf="$1"
	local plugin_line="$2"

	# Check if both markers exist
	local start_marker="#TPM plugins"
	local end_marker="#End of TPM plugins"

	if grep -q "^${start_marker}$" "$tmux_conf" && grep -q "^${end_marker}$" "$tmux_conf"; then
		# Both markers exist - insert between them (before end marker)
		# Use a temp file to avoid issues with in-place editing
		local temp_file
		temp_file=$(mktemp)

		awk -v plugin="$plugin_line" -v end_marker="$end_marker" '
			{
				print
				if ($0 == end_marker) {
					print plugin
				}
			}
		' "$tmux_conf" >"$temp_file" && mv "$temp_file" "$tmux_conf"
	else
		# Markers don't exist - create them and insert between
		# Check if file already has the start marker (partial setup)
		if grep -q "^${start_marker}$" "$tmux_conf"; then
			# Start marker exists, add end marker and plugin after it
			# Find line number of start marker and insert after it
			local temp_file
			temp_file=$(mktemp)
			local marker_line
			marker_line=$(grep -n "^${start_marker}$" "$tmux_conf" | cut -d: -f1)

			awk -v plugin="$plugin_line" -v marker_line="$marker_line" 'NR == marker_line { print; print ""; print "#End of TPM plugins"; print ""; print plugin; next } { print }' \
				"$tmux_conf" >"$temp_file" && mv "$temp_file" "$tmux_conf"
		else
			# Neither marker exists - append both markers with plugin between
			{
				echo ""
				echo "#TPM plugins"
				echo "$plugin_line"
				echo "#End of TPM plugins"
			} >>"$tmux_conf"
		fi
	fi
}

# Uncomment a commented plugin line in tmux.conf
uncomment_plugin() {
	local tmux_conf="$1"
	local plugin_name="$2"

	# Escape special characters in plugin name for sed
	local escaped_name
	escaped_name=$(printf '%s' "$plugin_name" | sed 's/[[\.*^$/&]/\\&/g')

	# Uncomment the line - handles various comment styles:
	# #set -g @plugin "name"
	# # set -g @plugin "name"
	#   #  set -g @plugin "name"
	sed -i -E "s|^[[:space:]]*#[[:space:]]*set[[:space:]]+-g[[:space:]]+@plugin[[:space:]]+[\"']${escaped_name}[\"']|set -g @plugin \"${escaped_name}\"|" "$tmux_conf"

	return 0
}

install_available_plugin() {
	# Get full plugin URL from cache
	plugin_url=$(get_available_plugin_url "$plugin_name")

	if [ -z "$plugin_url" ]; then
		# Fallback to github.com format - try tmux-plugins first
		plugin_url="https://github.com/tmux-plugins/${plugin_name}"
	fi

	# Add to tmux.conf between TPM markers
	tmux_conf=$(_get_user_tmux_conf)
	plugin_line='set -g @plugin "'"$plugin_name"'"'
	insert_plugin_between_markers "$tmux_conf" "$plugin_line"
	echo "Added to tmux.conf: $plugin_name"

	# Clone the plugin
	cd "$(tpm_path)" && GIT_TERMINAL_PROMPT=0 git clone --single-branch --recursive "$plugin_url" 2>&1

	if [ $? -eq 0 ]; then
		echo "Installed: $plugin_name"
		# Return success (don't exit) so fzf binding can trigger reload
		return 0
	else
		echo "Warning: Added to tmux.conf but clone failed. Run 'prefix + I' to install." >&2
		return 1
	fi
}

install_pending_plugin() {
	# Get the full plugin string from tmux.conf
	plugin_path="$(tpm_path)${plugin_name}/"

	# Try to clone the plugin
	cd "$(tpm_path)" && GIT_TERMINAL_PROMPT=0 git clone --single-branch --recursive "https://github.com/${plugin_name}" 2>&1

	if [ $? -eq 0 ]; then
		echo "Installed: $plugin_name"
		return 0
	else
		echo "Failed to install: $plugin_name" >&2
		return 1
	fi
}

# Install orphaned plugin by uncommenting it in tmux.conf
install_orphaned_plugin() {
	tmux_conf=$(_get_user_tmux_conf)

	# Try to uncomment the plugin
	uncomment_plugin "$tmux_conf" "$plugin_name"

	# Check if uncommenting succeeded (line should now be active)
	if grep -qE "^[[:space:]]*set[[:space:]]+-g[[:space:]]+@plugin[[:space:]]+[\"']${plugin_name//\//\\/}[\"']" "$tmux_conf" 2>/dev/null; then
		echo "Uncommented in tmux.conf: $plugin_name"
		return 0
	else
		echo "Warning: Plugin may already be active or not found in tmux.conf: $plugin_name" >&2
		return 0 # Don't fail, plugin might be in sourced file
	fi
}

main() {
	# Get plugin info from first argument (passed from fzf selection)
	# The selection format is: "[status]  plugin_name"
	plugin_line="$1"

	# Extract plugin name - remove status prefix like "[pending]  "
	plugin_name=$(echo "$plugin_line" | sed 's/^\[.*\][[:space:]]*//')

	if [ -z "$plugin_name" ]; then
		echo "Error: No plugin name provided" >&2
		exit 1
	fi

	# Check if it's a pending plugin (needs to be installed)
	status=$(echo "$plugin_line" | sed -E 's/^\[([^]]+)\].*/\1/')

	# Handle available plugins - add to tmux.conf AND clone
	if [ "$status" = "available" ]; then
		install_available_plugin
	# Handle orphaned plugins - uncomment in tmux.conf
	elif [ "$status" = "orphaned" ]; then
		install_orphaned_plugin
	# Handle pending plugins (existing logic)
	elif [ "$status" = "pending" ]; then
		install_pending_plugin
	else
		echo "Plugin already installed or unknown status: $plugin_name"
	fi
}

main "$@"
