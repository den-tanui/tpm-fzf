#!/usr/bin/env bash
# tpm-fzf setup script
# Interactive configuration and plugin grouping setup

set -e

TPM_FZF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TPM_FZF_DIR/lib/plugin_functions.sh"
source "$TPM_FZF_DIR/lib/utility.sh"
source "$TPM_FZF_DIR/scripts/variables.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Default markers (can be overridden by tmux options)
START_MARKER="$(get_tmux_option "$grouping_start_marker_option" "$default_grouping_start")"
END_MARKER="$(get_tmux_option "$grouping_end_marker_option" "$default_grouping_end")"

# Usage function
usage() {
	cat <<EOF
tpm-fzf setup - Configure plugin grouping and options

Usage: $(basename "$0") [OPTIONS]

Configuration Options:
  --grouping on|off        Enable/disable plugin grouping
  --start-marker TEXT     Set start marker (default: #TPM plugins)
  --end-marker TEXT      Set end marker (default: #End of plugin list)

Commands:
  -s, --setup          Full setup (add markers + migrate plugins)
  -m, --markers       Show current marker positions
  -e, --enable        Enable grouping
  -d, --disable       Disable grouping
  -h, --help         Show this help

Tmux Options (set in tmux.conf):
  @tpm-fzf-grouping-enabled  on/off (default: on)
  @tpm-fzf-grouping-start   Start marker
  @tpm-fzf-grouping-end    End marker

Examples:
  $(basename "$0") --setup              # Full setup with migration
  $(basename "$0") --grouping off    # Disable grouping
  $(basename "$0") --start-marker "# My Plugins"  # Custom markers
EOF
}

# Get user's tmux.conf location
get_tmux_conf() {
	xdg_location="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
	default_location="$HOME/.tmux.conf"

	if [ -f "$xdg_location" ]; then
		echo "$xdg_location"
	else
		echo "$default_location"
	fi
}

# Check if markers exist in tmux.conf
check_markers() {
	local conf="$1"
	if grep -q "^${START_MARKER}$" "$conf" 2>/dev/null &&
		grep -q "^${END_MARKER}$" "$conf" 2>/dev/null; then
		return 0
	fi
	return 1
}

# Find where to insert start marker (after critical options, before plugin config)
find_start_position() {
	local conf="$1"
	local line

	# Find last critical option line
	line=$(grep -n "^set.*-g.*terminal\|set.*-g.*status\|set.*-g.*history\|set.*-g.*escape" "$conf" 2>/dev/null | tail -1 | cut -d: -f1)

	if [ -n "$line" ]; then
		echo "$line"
		return
	fi

	# Find first @plugin or @tpm- line
	line=$(grep -n "^set.*-g.*@plugin\|^set.*-g.*@tpm-" "$conf" 2>/dev/null | head -1 | cut -d: -f1)

	if [ -n "$line" ]; then
		echo $((line - 1))
		return
	fi

	# Find run-shell tpm line
	line=$(grep -n "^run-shell.*tpm" "$conf" 2>/dev/null | head -1 | cut -d: -f1)

	if [ -n "$line" ]; then
		echo $((line - 1))
		return
	fi

	# Default: right before run-shell or end
	lines=$(wc -l <"$conf")
	echo "${lines:-1}"
}

# Find where to insert end marker (before plugin-specific config)
find_end_position() {
	local conf="$1"
	local line

	# Find first plugin-specific config (@plugin-name-*, not @tpm-*)
	line=$(awk -v start="$(grep -n "^${START_MARKER}$" "$conf" | head -1 | cut -d: -f1)" '
		$1 > start && /^set.*-g.*@[a-zA-Z]/ && !/^-g.*@tpm-/ {print $1; exit}
	' "$conf" 2>/dev/null | head -1)

	if [ -n "$line" ]; then
		echo "$((line - 1))"
		return
	fi

	# Find run-shell tpm line
	line=$(grep -n "^run-shell.*tpm" "$conf" 2>/dev/null | head -1 | cut -d: -f1)

	if [ -n "$line" ]; then
		echo $((line - 1))
		return
	fi

	# Default: end of file
	lines=$(wc -l <"$conf")
	echo "${lines:-1}"
}

# Extract all @plugin lines (including commented)
extract_plugins() {
	local conf="$1"
	grep -E "^[[:space:]]*(set[[:space:]]+-g[[:space:]]+)?@plugin" "$conf" 2>/dev/null |
		sed -E 's/^[[:space:]]*//'
}

# Create backup
backup_conf() {
	local conf="$1"
	local backup="${conf}.backup.$(date +%Y%m%d_%H%M%S)"
	cp "$conf" "$backup"
	echo "$backup"
}

# Add markers to tmux.conf
add_markers() {
	local conf="$1"

	if check_markers "$conf"; then
		echo -e "${YELLOW}Markers already exist in $conf${RESET}"
		return 1
	fi

	local backup
	backup=$(backup_conf "$conf")
	echo -e "${CYAN}Backup created: $backup${RESET}"

	local start_line end_line
	start_line=$(find_start_position "$conf")
	end_line=$(find_end_position "$conf")

	# Create new content
	local tmp=$(mktemp)

	# Copy lines before start marker
	if [ "$start_line" -gt 0 ]; then
		head -n "$((start_line - 1))" "$conf" >"$tmp"
	fi

	# Add start marker
	echo "$START_MARKER" >>"$tmp"

	# Add plugins
	extract_plugins "$conf" >>"$tmp"

	# Add end marker
	echo "$END_MARKER" >>"$tmp"

	# Add lines between end marker and plugin config or tpm source
	if [ "$end_line" -gt "$start_line" ]; then
		mid_start=$((start_line))
		mid_end=$((end_line))
		if [ "$mid_end" -gt "$mid_start" ]; then
			sed -n "$((mid_start + 2)),$((mid_end - 1))p" "$conf" >>"$tmp" 2>/dev/null || true
		fi
	fi

	# Add remaining content after end marker
	tail -n +$((end_line)) "$conf" >>"$tmp" 2>/dev/null || true

	# Replace original
	mv "$tmp" "$conf"

	echo -e "${GREEN}Markers added to $conf${RESET}"
}

# Migrate plugins to group
migrate_plugins() {
	local conf="$1"

	if ! check_markers "$conf"; then
		echo -e "${YELLOW}Adding markers first...${RESET}"
		add_markers "$conf"
	fi

	# Backup
	local backup
	backup=$(backup_conf "$conf")
	echo -e "${CYAN}Backup created: $backup${RESET}"

	# Extract all plugins
	local all_plugins
	all_plugins=$(extract_plugins "$conf")

	if [ -z "$all_plugins" ]; then
		echo -e "${YELLOW}No plugins found to migrate${RESET}"
		return
	fi

	# Remove existing plugins section and rebuild
	local tmp=$(mktemp)
	local in_plugins=0

	while IFS= read -r line; do
		case "$line" in
		"$START_MARKER")
			echo "$line" >>"$tmp"
			in_plugins=1
			;;
		"$END_MARKER")
			echo "$line" >>"$tmp"
			in_plugins=0
			;;
		*)
			if [ "$in_plugins" -eq 1 ]; then
				# Skip - will add from all_plugins
				:
			else
				echo "$line" >>"$tmp"
			fi
			;;
		esac
	done <"$conf"

	# Add all plugins between markers
	local plugin_tmp=$(mktemp)
	echo "$START_MARKER" >>"$plugin_tmp"

	# Deduplicate and add plugins
	local seen
	while IFS= read -r plugin; do
		case "$plugin" in
		set*)
			plugin=$(echo "$plugin" | sed 's/^set //')
			;;
		esac
		local name
		name=$(echo "$plugin" | awk '{print $NF}' | tr -d "'\"")
		if [ -z "${seen[$name]}" ]; then
			echo "set -g @plugin '$name'" >>"$plugin_tmp"
			seen[$name]=1
		fi
	done <<<"$all_plugins"

	echo "$END_MARKER" >>"$plugin_tmp"

	# Merge back
	local out=$(mktemp)
	local in_plugin_section=0
	while IFS= read -r line; do
		case "$line" in
		"$START_MARKER")
			cat "$plugin_tmp" >>"$out"
			in_plugin_section=1
			;;
		"$END_MARKER")
			in_plugin_section=0
			;;
		*)
			if [ "$in_plugin_section" -eq 0 ]; then
				echo "$line" >>"$out"
			fi
			;;
		esac
	done <"$tmp"

	mv "$out" "$conf"
	rm -f "$tmp" "$plugin_tmp"

	echo -e "${GREEN}Plugins migrated successfully${RESET}"
}

# Show markers position
show_markers() {
	local conf="$1"

	if check_markers "$conf"; then
		echo -e "${GREEN}Markers found in $conf${RESET}"
		local start=$(grep -n "^${START_MARKER}$" "$conf" | cut -d: -f1)
		local end=$(grep -n "^${END_MARKER}$" "$conf" | cut -d: -f1)
		echo "  Start: line $start"
		echo "  End: line $end"

		# Count plugins
		local count
		count=$(awk -v s="$start" -v e="$end" 'NR > s && NR < e && /@plugin/ {count++} END {print count+0}' "$conf")
		echo "  Plugins: $count"
	else
		echo -e "${YELLOW}No markers found in $conf${RESET}"
	fi
}

# Interactive setup
interactive_setup() {
	local conf
	conf=$(get_tmux_conf)

	echo -e ""
	echo -e "${BOLD}tpm-fzf Setup${RESET}"
	echo -e "=================="
	echo -e ""
	echo -e "Configuration file: ${CYAN}$conf${RESET}"
	echo -e ""

	# Check current state
	if check_markers "$conf"; then
		echo -e "${GREEN}Plugin grouping is ENABLED${RESET}"
	else
		echo -e "${YELLOW}Plugin grouping is NOT enabled${RESET}"
	fi
	echo -e ""

	# Menu
	echo "Choose an option:"
	echo "  1) Enable plugin grouping"
	echo "  2) Disable plugin grouping"
	echo "  3) Full setup (migrate existing plugins)"
	echo "  4) Show marker positions"
	echo "  5) View tmux.conf"
	echo "  6) Quit"
	echo -n "> "

	local choice
	read choice

	case "$choice" in
	1)
		add_markers "$conf"
		;;
	2)
		echo -e "${YELLOW}Disabling grouping not implemented yet${RESET}"
		;;
	3)
		migrate_plugins "$conf"
		;;
	4)
		show_markers "$conf"
		;;
	5)
		less "$conf"
		;;
	6)
		echo "Goodbye!"
		exit 0
		;;
	*)
		echo -e "${RED}Invalid choice${RESET}"
		exit 1
		;;
	esac
}

# Main
main() {
	# Parse arguments
	local mode="setup" # Default to full setup
	local do_setup=0

	while [ $# -gt 0 ]; do
		case "$1" in
		-i | --interactive)
			mode="interactive"
			;;
		-e | --enable-grouping)
			mode="enable"
			;;
		-d | --disable-grouping)
			mode="disable"
			;;
		-s | --setup)
			mode="setup"
			do_setup=1
			;;
		-m | --markers)
			mode="markers"
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo -e "${RED}Unknown option: $1${RESET}"
			usage
			exit 1
			;;
		esac
		shift
	done

	local conf
	conf=$(get_tmux_conf)

	if [ ! -f "$conf" ]; then
		echo -e "${RED}tmux.conf not found: $conf${RESET}"
		exit 1
	fi

	case "$mode" in
	interactive)
		interactive_setup
		;;
	enable)
		add_markers "$conf"
		;;
	disable)
		echo "Disable not implemented"
		;;
	setup)
		migrate_plugins "$conf"
		;;
	markers)
		show_markers "$conf"
		;;
	esac
}

main "$@"
