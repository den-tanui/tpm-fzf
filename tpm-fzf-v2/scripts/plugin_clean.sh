#!/usr/bin/env bash

# Clean orphaned plugins for tpm_fzf_v2

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

# Clean orphaned plugins
clean_orphaned() {
  local pdir
  pdir=$(get_plugin_dir_ex)
  
  # Get plugins we want (from tmux.conf)
  local wanted_plugins
  wanted_plugins=$(get_plugins_between_markers)
  
  if [ ! -d "$pdir" ]; then
    echo "No plugin directory"
    return 1
  fi
  
  local cleaned=0
  
  for plugin_path in "$pdir"*; do
    [ -d "$plugin_path" ] || continue
    [ -d "$plugin_path/.git" ] || continue
    
    local plugin_name
    plugin_name=$(basename "$plugin_path")
    
    # Skip tpm-fzf-v2 itself
    [ "$plugin_name" = "tpm-fzf-v2" ] && continue
    
    # Check if in tmux.conf
    if ! echo "$wanted_plugins" | grep -q "^${plugin_name}$"; then
      rm -rf "$plugin_path"
      echo "Cleaned: $plugin_name"
      cleaned=$((cleaned + 1))
    fi
  done
  
  if [ $cleaned -eq 0 ]; then
    echo "No orphaned plugins to clean"
  else
    echo "Cleaned $cleaned plugin(s)"
  fi
}

# Main
main() {
  clean_orphaned
}

main "$@"