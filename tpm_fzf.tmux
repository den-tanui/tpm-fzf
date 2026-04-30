#!/usr/bin/env bash
# tpm-fzf initialization
# This file is sourced by TPM to initialize the plugin

TPM_FZF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bind prefix+i to show popup with plugin list
tmux bind-key "i" display-popup -w 80% -h 80% -B -E bash -c "$TPM_FZF_DIR/scripts/plugin_list.sh"