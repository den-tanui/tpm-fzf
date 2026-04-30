#!/usr/bin/env bash

# Plugin functions for tpm_fzf_v2
# Adapted from TPM's plugin_functions.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# Get plugin directory from tmux option or default
get_plugin_dir() {
  local default_dir="${HOME}/.tmux/plugins/"
  local plugin_dir
  plugin_dir="$(tmux show-option -gqv "@tpm_fzf_plugin_dir" 2>/dev/null)"
  if [ -z "$plugin_dir" ]; then
    echo "$default_dir"
  else
    # Expand ~ 
    echo "${plugin_dir/~/$HOME}"
  fi
}

# Get tmux.conf path
get_tmux_conf_path() {
  local default_conf="${HOME}/.tmux.conf"
  local xdg_conf="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
  local conf_path
  conf_path="$(tmux show-option -gqv "@tpm_fzf_tmux_conf" 2>/dev/null)"
  if [ -n "$conf_path" ]; then
    echo "${conf_path/~/$HOME}"
  elif [ -f "$xdg_conf" ]; then
    echo "$xdg_conf"
  elif [ -f "$default_conf" ]; then
    echo "$default_conf"
  else
    echo "$default_conf"
  fi
}

# Get plugins config file path
get_plugins_config() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  script_dir="$(dirname "$script_dir")"
  local default_conf="${script_dir}/plugins.conf"
  local conf_path
  conf_path="$(tmux show-option -gqv "@tpm_fzf_plugins_config" 2>/dev/null)"
  if [ -n "$conf_path" ]; then
    echo "${conf_path/~/$HOME}"
  else
    echo "$default_conf"
  fi
}

# Get git command (git clone or gh repo clone)
get_git_command() {
  local git_cmd
  git_cmd="$(tmux show-option -gqv "@tpm_fzf_git_command" 2>/dev/null)"
  echo "${git_cmd:-git clone}"
}

# Extract author/repo from GitHub URL
plugin_name_from_url() {
  local url="$1"
  # Remove trailing .git if present
  url="${url%.git}"
  # Get last two path segments
  local repo
  repo=$(echo "$url" | sed 's|.*github.com/||')
  echo "$repo"
}

# Extract URL from GitHub URL (clean format)
clean_url() {
  local input="$1"
  # Handle various formats
  input="${input#https://github.com/}"
  input="${input#git@github.com:}"
  input="${input%.git}"
  echo "$input"
}

# Get only the plugin name (repo) from full path
plugin_basename() {
  local plugin="$1"
  basename "$plugin"
}

# Get full path to plugin directory
plugin_path() {
  local plugin="$1"
  local plugin_name
  plugin_name=$(plugin_basename "$plugin")
  echo "$(get_plugin_dir)${plugin_name}/"
}

# Check if plugin is installed and is a git repo
is_plugin_installed() {
  local plugin="$1"
  local ppath
  ppath=$(plugin_path "$plugin")
  [ -d "$ppath" ] && [ -d "$ppath/.git" ]
}

# List installed plugins (directories in plugin dir)
get_installed_plugins() {
  local pdir
  pdir=$(get_plugin_dir)
  if [ -d "$pdir" ]; then
    for dir in "$pdir"*; do
      [ -d "$dir/.git" ] && basename "$dir"
    done
  fi
}

# List all plugins from config file
get_available_plugins() {
  local conf
  conf=$(get_plugins_config)
  if [ -f "$conf" ]; then
    # Skip comments and empty lines
    grep -v '^#' "$conf" | grep -v '^$' | while read -r url; do
      plugin_name_from_url "$url"
    done
  fi
}

# Parse plugins from tmux.conf
get_plugins_from_conf() {
  local conf
  conf=$(get_tmux_conf_path)
  if [ -f "$conf" ]; then
    # Extract @plugin lines, handle both quoted and unquoted
    grep -E '^[[:space:]]*set[[:space:]]+-g[[:space:]]+@plugin' "$conf" | \
      sed -E 's/.*@plugin[[:space:]]+["'\'']([^"'\'']+)["'\''Dj.*/\1/' | \
      grep -v '^#' | sort -u
  fi
}

# Get all plugins (including commented)
get_all_plugins_from_conf() {
  local conf
  conf=$(get_tmux_conf_path)
  if [ -f "$conf" ]; then
    grep -E '^[[:space:]]*(#[[:space:]]*)?set[[:space:]]+-g[[:space:]]+@plugin' "$conf" | \
      sed -E 's/.*@plugin[[:space:]]+["'\'']([^"'\'']+)["'\''Dj.*/\1/' | sort -u
  fi
}

# Get just the plugin name part
get_plugin_name() {
  local plugin="$1"
  # Remove path and .git
  local name
  name=$(basename "$plugin")
  name="${name%.git}"
  echo "$name"
}