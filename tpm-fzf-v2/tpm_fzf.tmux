#!/usr/bin/env bash

# tpm_fzf.tmux - Main plugin file
# Provides tmux integration for tpm_fzf_v2
# Similar to TPM's tpm file but with fzf features

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# Source helper functions
# shellcheck source=scripts/variables.sh
source "${SCRIPT_DIR}/scripts/variables.sh"

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

# Check if tmux version is supported (2.17+)
check_tmux_version() {
  local required="2.17"
  local version
  version=$(tmux -V 2>/dev/null | sed 's/tmux //')
  
  if [ -z "$version" ]; then
    return 1
  fi
  
  # Simple version check
  if [ "$(printf '%s\n' "$required" "$version" | sort -V | head -n1)" = "$required" ] && [ "$version" != "$required" ]; then
    return 0
  elif [ "$version" = "$required" ]; then
    return 0
  elif [ "$(printf '%s\n' "$required" "$version" | sort -V | head -n1)" = "$required" ]; then
    return 0
  fi
  
  return 1
}

# Set default plugin directory
set_plugin_dir() {
  local plugin_dir
  plugin_dir="$(get_tmux_option "@tpm_fzf_plugin_dir" "")"
  
  if [ -z "$plugin_dir" ]; then
    # Set default
    tmux set-option -g @tpm_fzf_plugin_dir "${HOME}/.tmux/plugins/"
  fi
}

# Set default tmux.conf path
set_tmux_conf() {
  local tmux_conf
  tmux_conf="$(get_tmux_option "@tpm_fzf_tmux_conf" "")"
  
  if [ -z "$tmux_conf" ]; then
    # Check XDG first
    local xdg_conf="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
    if [ -f "$xdg_conf" ]; then
      tmux set-option -g @tpm_fzf_tmux_conf "$xdg_conf"
    elif [ -f "${HOME}/.tmux.conf" ]; then
      tmux set-option -g @tpm_fzf_tmux_conf "${HOME}/.tmux.conf"
    else
      tmux set-option -g @tpm_fzf_tmux_conf "${HOME}/.tmux.conf"
    fi
  fi
}

# Set default plugins config path
set_plugins_config() {
  local plugins_conf
  plugins_conf="$(get_tmux_option "@tpm_fzf_plugins_config" "")"
  
  if [ -z "$plugins_conf" ]; then
    tmux set-option -g @tpm_fzf_plugins_config "${SCRIPT_DIR}/plugins.conf"
  fi
}

# Set default git command
set_git_command() {
  local git_cmd
  git_cmd="$(get_tmux_option "@tpm_fzf_git_command" "")"
  
  if [ -z "$git_cmd" ]; then
    tmux set-option -g @tpm_fzf_git_command "git clone"
  fi
}

# Set default key binding
set_key() {
  local key
  key="$(get_tmux_option "@tpm_fzf_key" "")"
  
  if [ -z "$key" ]; then
    tmux set-option -g @tpm_fzf_key "i"
  fi
}

# Set default popup dimensions
set_popup_dimensions() {
  local popup_w
  popup_w="$(get_tmux_option "@tpm_fzf_popup_w" "")"
  
  if [ -z "$popup_w" ]; then
    tmux set-option -g @tpm_fzf_popup_w 80
  fi
  
  local popup_h
  popup_h="$(get_tmux_option "@tpm_fzf_popup_h" "")"
  
  if [ -z "$popup_h" ]; then
    tmux set-option -g @tpm_fzf_popup_h 80
  fi
}

# Source all *.tmux files from installed plugins
source_plugins() {
  "${SCRIPT_DIR}/scripts/plugin_source.sh" >/dev/null 2>&1
}

# Set keybindings
set_key_bindings() {
  local key
  key="$(get_tmux_option "@tpm_fzf_key" "i")"
  
  # Main binding: prefix + I opens fzf popup
  tmux bind-key "$key" run-shell -b "bash '${SCRIPT_DIR}/scripts/plugin_list.sh'"
  
  # Optional: TPM-compatible bindings (can be overridden)
  # prefix + U - update all
  tmux bind-key U run-shell -b "bash '${SCRIPT_DIR}/scripts/plugin_update.sh all'"
  
  # prefix + alt + u - clean all (like TPM's alt+u)
  tmux bind-key M-u run-shell -b "bash '${SCRIPT_DIR}/scripts/plugin_clean.sh'"
  
  # prefix + I - install (same as main)
  # tmux bind-key I run-shell -b "bash '${SCRIPT_DIR}/scripts/plugin_list.sh'"
}

# Main initialization
main() {
  # Check tmux version
  if ! check_tmux_version; then
    # Display error but continue
    tmux display-message "tpm_fzf_v2: tmux version 2.17+ required" 2>/dev/null
  fi
  
  # Set defaults
  set_plugin_dir
  set_tmux_conf
  set_plugins_config
  set_git_command
  set_key
  set_popup_dimensions
  
  # Source plugins (our implementation)
  source_plugins
  
  # Set keybindings
  set_key_bindings
}

# Run main
main