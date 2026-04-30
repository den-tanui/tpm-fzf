#!/usr/bin/env bash

# Variables and tmux option getters for tpm_fzf_v2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
DEFAULT_PLUGIN_DIR="${HOME}/.tmux/plugins/"
DEFAULT_TMUX_CONF="${HOME}/.tmux.conf"
DEFAULT_GIT_COMMAND="git clone"
DEFAULT_KEY="i"
DEFAULT_POPUP_W=80
DEFAULT_POPUP_H=80

# Get tmux option with default
get_tmux_option() {
  local option="$1"
  local default="$2"
  local value
  value="$(tmux show-option -gqv "$option" 2>/dev/null)"
  if [ -z "$value" ]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# Get a tmux option (returns default if not set)
tpm_option() {
  local option="$1"
  local default="$2"
  local value
  value="$(tmux show-option -gqv "$option" 2>/dev/null)"
  [ -z "$value" ] && value="$default"
  echo "$value"
}

# Plugin directory
get_plugin_dir() {
  tpm_option "@tpm_fzf_plugin_dir" "$DEFAULT_PLUGIN_DIR"
}

# Tmux.conf path  
get_tmux_conf() {
  local xdg_conf="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
  local default_conf="$DEFAULT_TMUX_CONF"
  local conf
  
  conf="$(tmux show-option -gqv "@tpm_fzf_tmux_conf" 2>/dev/null)"
  if [ -n "$conf" ]; then
    echo "$conf"
  elif [ -f "$xdg_conf" ]; then
    echo "$xdg_conf"
  elif [ -f "$default_conf" ]; then
    echo "$default_conf"
  else
    echo "$default_conf"
  fi
}

# Plugins config file
get_plugins_config() {
  local default_conf="${SCRIPT_DIR}/plugins.conf"
  
  conf="$(tmux show-option -gqv "@tpm_fzf_plugins_config" 2>/dev/null)"
  if [ -n "$conf" ]; then
    echo "$conf"
  else
    echo "$default_conf"
  fi
}

# Git command
get_git_command() {
  tpm_option "@tpm_fzf_git_command" "$DEFAULT_GIT_COMMAND"
}

# Key binding
get_key() {
  tpm_option "@tpm_fzf_key" "$DEFAULT_KEY"
}

# Popup dimensions
get_popup_w() {
  tpm_option "@tpm_fzf_popup_w" "$DEFAULT_POPUP_W"
}

get_popup_h() {
  tpm_option "@tpm_fzf_popup_h" "$DEFAULT_POPUP_H"
}

# Source this script's helpers
# shellcheck source=SCRIPTDIR/../lib/plugin_functions.sh
source_lib() {
  local lib_file="${SCRIPT_DIR}/lib/plugin_functions.sh"
  if [ -f "$lib_file" ]; then
    # shellcheck disable=SC1090
    source "$lib_file"
  fi
}

# Export for use in subshells
export PLUGIN_DIR="$(get_plugin_dir)"
export TMUX_CONF="$(get_tmux_conf)"
export PLUGINS_CONFIG="$(get_plugins_config)"
export GIT_COMMAND="$(get_git_command)"