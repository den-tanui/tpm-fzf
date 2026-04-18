#!/usr/bin/env bash
# Plugin preview script - shows README from local or GitHub

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$CURRENT_DIR")/lib"

source "$LIB_DIR/plugin_functions.sh"
source "$LIB_DIR/utility.sh"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Preview a README file (local or remote temp file)
preview_readme() {
	local readme_file="$1"
	if [ -f "$readme_file" ]; then
		if command -v bat &>/dev/null; then
			bat --force-colorization --language=markdown --style=plain --wrap=auto "$readme_file"
		else
			cat "$readme_file"
		fi
	else
		echo "(File not found)"
	fi
}

# Fetch README from GitHub repo using git
fetch_readme_github() {
	local repo_url="$1"
	local tmp_dir
	tmp_dir=$(mktemp -d)

	# Initialize empty git repo
	cd "$tmp_dir"
	git init -q 2>/dev/null
	git remote add origin "$repo_url" 2>/dev/null

	# Try master then main
	local branch="master"
	if ! git fetch -q --depth 1 origin "refs/heads/${branch}:refs/remotes/origin/${branch}" 2>/dev/null; then
		branch="main"
		git fetch -q --depth 1 origin "refs/heads/${branch}:refs/remotes/origin/${branch}" 2>/dev/null
	fi

	if [ $? -eq 0 ]; then
		# Checkout the branch
		git checkout -q -f "$branch" 2>/dev/null

		# Find README
		local readme_file=""
		for name in README.md readme.md README readme; do
			if [ -f "${tmp_dir}/${name}" ]; then
				readme_file="${tmp_dir}/${name}"
				break
			fi
		done

		if [ -n "$readme_file" ]; then
			cat "$readme_file"
		else
			echo "(No README found in repository)"
		fi
	else
		echo "(Failed to fetch from repository)"
	fi

	rm -rf "$tmp_dir"
}

main() {
	local selection="$1"
	local plugin_name
	plugin_name="$(echo "$selection" | sed 's/.*]  *//')"

	# Extract status from selection
	local status
	status="$(echo "$selection" | sed -E 's/^\[(.*)\].*/\1/')"

	# Check if available plugin - special handling
	if [ "$status" = "available" ]; then
		local available_name="$plugin_name"

		echo -e "${GREEN}Plugin:${RESET} $available_name"
		echo -e "${GREEN}Status:${RESET} Available (from TPM repository)"
		echo ""

		# Get URL from cache
		local plugin_url
		plugin_url=$(get_available_plugin_url "$available_name")
		if [ -n "$plugin_url" ]; then
			echo -e "${GREEN}GitHub:${RESET} $plugin_url"
		else
			echo -e "${GREEN}GitHub:${RESET} https://github.com/$available_name"
		fi
		echo ""

		# Fetch README using git
		echo -e "${YELLOW}Fetching README from GitHub...${RESET}"

		local repo_url="${plugin_url:-https://github.com/tmux-plugins/${available_name}}"
		local github_readme
		github_readme=$(fetch_readme_github "$repo_url")

		if [ -n "$github_readme" ]; then
			# Save to temp file and preview
			local tmp_file
			tmp_file=$(mktemp)
			printf "%s\n" "$github_readme" >"$tmp_file"
			preview_readme "$tmp_file"
			rm -f "$tmp_file"
		else
			echo "(No README found on GitHub)"
		fi
		return
	fi

	local plugin_path
	plugin_path="$(plugin_path_helper "$plugin_name")"

	echo -e "${GREEN}Plugin:${RESET} $plugin_name"
	echo -e "${GREEN}Path:${RESET} $plugin_path"
	echo ""

	# Check for local README (case-insensitive)
	local readme=""
	if [ -f "${plugin_path}README.md" ]; then
		readme="${plugin_path}README.md"
	elif [ -f "${plugin_path}readme.md" ]; then
		readme="${plugin_path}readme.md"
	elif [ -f "${plugin_path}README" ]; then
		readme="${plugin_path}README"
	elif [ -f "${plugin_path}readme" ]; then
		readme="${plugin_path}readme"
	fi

	if [ -n "$readme" ]; then
		preview_readme "$readme"
	elif [ "$status" = "pending" ]; then
		# For pending plugins, try to fetch README from GitHub
		echo -e "${YELLOW}Fetching README from GitHub...${RESET}"

		local repo_url="https://github.com/${plugin_name}"
		local github_readme
		github_readme=$(fetch_readme_github "$repo_url")

		if [ -n "$github_readme" ]; then
			local tmp_file
			tmp_file=$(mktemp)
			printf "%s\n" "$github_readme" >"$tmp_file"
			preview_readme "$tmp_file"
			rm -f "$tmp_file"
		else
			echo "(No README found locally or on GitHub)"
		fi
	else
		echo "(No README found)"
	fi
}

main "$1"
