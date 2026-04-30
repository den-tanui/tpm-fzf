#!/usr/bin/env bash

# Source all *.tmux files from installed plugins
# Replaces TPM's source_plugins.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=scripts/variables.sh
source "${SCRIPT_DIR}/scripts/variables.sh"

get_plugin_dir_ex() {
  local pdir
  pdir=$(get_plugin_dir)
  echo "${pdir/~/$HOME}"
}

# Source all *.tmux files from plugins
source_plugins() {
  local pdir
  pdir=$(get_plugin_dir_ex)
  
  if [ ! -d "$pdir" ]; then
    return 0
  fi
  
  # Get plugins from tmux.conf
  local plugins
  plugins=$(grep -E '^[[:space:]]*set[[:space:]]+-g[[:space:]]+@plugin' "$(get_tmux_conf)" 2>/dev/null | \
    sed -E 's/.*@plugin[[:space:]]+["'\'']([^"'\'']+)["'\''].*/\1/' | \
    grep -v '^[[:space:]]*#')
  
  # Source in order
  while IFS= read -r plugin; do
    [ -z "$plugin" ] && continue
    
    local plugin_path="${pdir}${plugin}"
    local tmux_files="${plugin_path}"/*.tmux
    
    if [ -d "$plugin_path" ]; then
      for tmux_file in $tmux_files; do
        [ -f "$tmux_file" ] || continue
        # Source as tmux config (not bash)
        tmux source-file "$tmux_file" 2>/dev/null
      done
    fi
  done <<< "$plugins"
}

# Run on load
source_plugins