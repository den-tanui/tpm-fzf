#!/usr/bin/env bash

# Remove a plugin for tpm_fzf_v2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=scripts/variables.sh
source "${SCRIPT_DIR}/scripts/variables.sh"
# shellcheck source=scripts/parse_tmux_conf.sh
source "${SCRIPT_DIR}/scripts/parse_tmux_conf.sh"

get_plugin_dir_ex() {
  local pdir
  pdir=$(get_plugin_dir)
  echo "${pdir/~/$HOME}"
}

# Remove a single plugin
remove_single() {
  local plugin="$1"
  local pdir
  pdir=$(get_plugin_dir_ex)
  
  local plugin_name
  plugin_name=$(basename "$plugin")
  
  # Comment out in tmux.conf
  remove_plugin "$plugin"
  
  # Delete plugin directory
  if [ -d "${pdir}${plugin_name}" ]; then
    rm -rf "${pdir}${plugin_name}"
    echo "Removed: $plugin_name"
  else
    echo "Directory not found: $plugin_name"
  fi
}

# Main
main() {
  local target="${1:-}"
  
  if [ -n "$target" ]; then
    remove_single "$target"
  else
    echo "Usage: $0 <plugin>"
    echo "  Remove a plugin (comments out in tmux.conf, deletes directory)"
    exit 1
  fi
}

main "$@"