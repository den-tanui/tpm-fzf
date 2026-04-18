#!/usr/bin/env bash
# tpm-fzf initialization
# This file is sourced by TPM to initialize the plugin

TPM_FZF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$TPM_FZF_DIR/lib/plugin_functions.sh"
source "$TPM_FZF_DIR/scripts/variables.sh"

# Set default keybinding if TPM is installed and key not already set
_tpm_fzf_set_keybinding() {
	local key
	key="$(get_tmux_option "$key_option" "$default_key")"
	
	# Check if already bound
	if ! tmux list-keys -g 2>/dev/null | grep -q "fzf-plugins"; then
		tmux bind-key -n M-"$key" run-shell -b "$TPM_FZF_DIR/bin/fzf-plugins"
	fi
}

# Initialize if TPM is available
_tpm_fzf_init() {
	local tpm_path
	tpm_path="$(tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH 2>/dev/null | cut -f2 -d=)"
	
	if [ -n "$tpm_path" ] && [ -d "${tpm_path}tpm" ]; then
		_tpm_fzf_set_keybinding
	fi
}

# Run initialization
_tpm_fzf_init