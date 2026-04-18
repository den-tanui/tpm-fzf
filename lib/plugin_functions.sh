# using @tpm_plugins is now deprecated in favor of using @plugin syntax
tpm_plugins_variable_name="@tpm_plugins"

# manually expanding tilde char or `$HOME` variable.
_manual_expansion() {
	local path="$1"
	local expanded_tilde="${path/#\~/$HOME}"
	echo "${expanded_tilde/#\$HOME/$HOME}"
}

_tpm_path() {
	local string_path="$(tmux start-server\; show-environment -g TMUX_PLUGIN_MANAGER_PATH | cut -f2 -d=)/"
	_manual_expansion "$string_path"
}

_CACHED_TPM_PATH="$(_tpm_path)"

# Get the absolute path to the users configuration file of TMux.
# This includes a prioritized search on different locations.
#
_get_user_tmux_conf() {
	# Define the different possible locations.
	xdg_location="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
	default_location="$HOME/.tmux.conf"

	# Search for the correct configuration file by priority.
	if [ -f "$xdg_location" ]; then
		echo "$xdg_location"

	else
		echo "$default_location"
	fi
}

_tmux_conf_contents() {
	user_config=$(_get_user_tmux_conf)
	cat /etc/tmux.conf "$user_config" 2>/dev/null
	if [ "$1" == "full" ]; then # also output content from sourced files
		local file
		for file in $(_sourced_files); do
			cat $(_manual_expansion "$file") 2>/dev/null
		done
	fi
}

# return files sourced from tmux config files
_sourced_files() {
	_tmux_conf_contents |
		sed -E -n -e "s/^[[:space:]]*source(-file)?[[:space:]]+(-q+[[:space:]]+)?['\"]?([^'\"]+)['\"]?/\3/p"
}

# Want to be able to abort in certain cases
trap "exit 1" TERM
export TOP_PID=$$

_fatal_error_abort() {
	echo >&2 "Aborting."
	kill -s TERM $TOP_PID
}

# PUBLIC FUNCTIONS BELOW

tpm_path() {
	if [ "$_CACHED_TPM_PATH" == "/" ]; then
		echo >&2 "FATAL: Tmux Plugin Manager not configured in tmux.conf"
		_fatal_error_abort
	fi
	echo "$_CACHED_TPM_PATH"
}

tpm_plugins_list_helper() {
	# lists plugins from @tpm_plugins option
	echo "$(tmux start-server\; show-option -gqv "$tpm_plugins_variable_name")"

	# read set -g @plugin "tmux-plugins/tmux-example-plugin" entries
	_tmux_conf_contents "full" |
		awk '/^[ \t]*set(-option)? +-g +@plugin/ { gsub(/'\''/,""); gsub(/'\"'/,""); print $4 }'
}

# Allowed plugin name formats:
# 1. "git://github.com/user/plugin_name.git"
# 2. "user/plugin_name"
plugin_name_helper() {
	local plugin="$1"
	# get only the part after the last slash, e.g. "plugin_name.git"
	local plugin_basename="$(basename "$plugin")"
	# remove ".git" extension (if it exists) to get only "plugin_name"
	local plugin_name="${plugin_basename%.git}"
	echo "$plugin_name"
}

plugin_path_helper() {
	local plugin="$1"
	local plugin_name="$(plugin_name_helper "$plugin")"
	echo "$(tpm_path)${plugin_name}/"
}

plugin_already_installed() {
	local plugin="$1"
	local plugin_path="$(plugin_path_helper "$plugin")"
	[ -d "$plugin_path" ] &&
		cd "$plugin_path" &&
		git remote >/dev/null 2>&1
}
# Get list of all plugins in plugin directory (regardless of tmux.conf)
get_local_plugins() {
	local plugin plugin_directory
	for plugin_directory in "$(tpm_path)"/*; do
		[ -d "${plugin_directory}" ] || continue
		plugin="$(plugin_name_helper "${plugin_directory}")"
		[ "${plugin}" = "tpm" ] && continue
		echo "${plugin}"
	done
}

# Categorize plugins into pending/installed/orphaned
# Output format: status|plugin_name|plugin_path
categorize_plugins() {
	local plugins plugin installed_plugins

	# Get plugins from tmux.conf
	plugins="$(tpm_plugins_list_helper)"
	installed_plugins="$(get_local_plugins)"

	# Check each plugin in tmux.conf - mark as pending or installed
	for plugin in $plugins; do
		if plugin_already_installed "$plugin"; then
			echo "installed|${plugin}|$(plugin_path_helper "$plugin")"
		else
			echo "pending|${plugin}|$(plugin_path_helper "$plugin")"
		fi
	done

	# Find orphaned plugins (in dir but not in tmux.conf)
	for plugin in $installed_plugins; do
		case "${plugins}" in
		*"${plugin}"*) : ;;
		*) echo "orphaned|${plugin}|$(tpm_path)${plugin}/" ;;
		esac
	done
}

# ========== Available Plugins (from TPM repository) ==========

# Cache directory and file
TPM_CACHE_DIR="$HOME/.cache/tpm"
AVAILABLE_PLUGINS_CACHE="$TPM_CACHE_DIR/available_plugins.txt"

# Ensure cache directory exists
ensure_cache_dir() {
	mkdir -p "$TPM_CACHE_DIR"
}

# Fetch available plugins from TPM repository (markdown format)
fetch_available_plugins() {
	local url="https://raw.githubusercontent.com/tmux-plugins/list/master/README.md"

	if command -v perl &>/dev/null; then
		curl -s --max-time 10 "$url" 2>/dev/null |
			perl -ne 'if (/^-\s+\[([^\]]+)\]\(([^)]+)\)(.*)/) { my ($n, $u, $d) = ($1, $2, $3); $d =~ s/^\s*-\s*//; print "$n|$u|$d\n"; }'
	elif command -v python3 &>/dev/null; then
		python3 -c "
import re, urllib.request
url = 'https://raw.githubusercontent.com/tmux-plugins/list/master/README.md'
content = urllib.request.urlopen(url).read().decode()
for line in content.split('\n'):
    if line.startswith('- ['):
        match = re.match(r'- \[([^\]]+)\]\(([^)]+)\)(.*)', line)
        if match:
            name, url, desc = match.groups()
            desc = desc.lstrip(' -').strip()
            print(f'{name}|{url}|{desc}')
"
	else
		# Fallback: grep-based (less accurate, may miss some)
		curl -s --max-time 10 "$url" 2>/dev/null |
			grep -E '^\- \[' |
			sed -n 's/^- \[\([^]]*\)\](\([^)]*\)).*/\1|\2/p'
	fi
}

# Get available plugins (from cache or fetch)
get_available_plugins() {
	local now timestamp age cache_age=86400 # 24 hours

	# Check if cache exists
	if [ -f "$AVAILABLE_PLUGINS_CACHE" ]; then
		now=$(date +%s)
		timestamp=$(stat -c %Y "$AVAILABLE_PLUGINS_CACHE" 2>/dev/null || echo 0)
		age=$((now - timestamp))

		# Return cached data if fresh enough
		if [ "$age" -lt "$cache_age" ]; then
			cat "$AVAILABLE_PLUGINS_CACHE"
			return
		fi
	fi

	# Fetch fresh data
	ensure_cache_dir
	fetch_available_plugins >"$AVAILABLE_PLUGINS_CACHE" 2>/dev/null
	cat "$AVAILABLE_PLUGINS_CACHE"
}

# Get the cache file path
get_available_plugins_cache_file() {
	echo "$AVAILABLE_PLUGINS_CACHE"
}

# Filter out plugins that are already pending/installed/orphaned
filter_available_plugins() {
	local existing_plugins

	# Get all existing plugins (pending + installed + orphaned)
	existing_plugins="$(tpm_plugins_list_helper)
$(get_local_plugins)"

	# Get available plugins and filter
	get_available_plugins | while IFS='|' read -r name url desc; do
		[ -z "$name" ] && continue
		# Extract short name (after last slash)
		short_name="${name##*/}"

		# Check if already exists
		case "$existing_plugins" in
		*"$name"* | *"/$short_name"* | *"$short_name"*) : ;;
		*) echo "$name|$url|$desc" ;;
		esac
	done
}

# Force refresh available plugins cache
refresh_available_plugins_cache() {
	ensure_cache_dir
	fetch_available_plugins >"$AVAILABLE_PLUGINS_CACHE" 2>/dev/null
}

# Get URL for available plugin from cache
get_available_plugin_url() {
	local plugin_name="$1"
	local cache_file="$AVAILABLE_PLUGINS_CACHE"

	if [ ! -f "$cache_file" ]; then
		# Fetch and cache
		get_available_plugins >/dev/null 2>&1
	fi

	if [ -f "$cache_file" ]; then
		# Grep-based lookup
		grep "^${plugin_name}|" "$cache_file" | cut -d'|' -f2
	fi
}
