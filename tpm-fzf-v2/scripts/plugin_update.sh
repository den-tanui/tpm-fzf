#!/usr/bin/env bash

# Update plugin(s) for tpm_fzf_v2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=scripts/variables.sh
source "${SCRIPT_DIR}/scripts/variables.sh"

get_plugin_dir_ex() {
  local pdir
  pdir=$(get_plugin_dir)
  echo "${pdir/~/$HOME}"
}

# Update a single plugin
update_single() {
  local plugin="$1"
  local pdir
  pdir=$(get_plugin_dir_ex)
  
  local plugin_name
  plugin_name=$(basename "$plugin")
  local plugin_path="${pdir}${plugin_name}"
  
  if [ ! -d "$plugin_path" ]; then
    echo "Not installed: $plugin_name"
    return 1
  fi
  
  cd "$plugin_path" || return 1
  
  # Get current version
  local old_version
  old_version=$(git describe --tags --abbrev=0 2>/dev/null)
  
  # Fetch and pull
  git fetch --all --tags 2>/dev/null
  
  # Pull changes
  local current_branch
  current_branch=$(git branch --show-current)
  if [ -n "$current_branch" ]; then
    git pull origin "$current_branch" 2>/dev/null
  else
    git pull 2>/dev/null
  fi
  
  # Get new version
  local new_version
  new_version=$(git describe --tags --abbrev=0 2>/dev/null)
  
  if [ "$old_version" != "$new_version" ] && [ -n "$new_version" ]; then
    echo "Updated: $plugin_name ($old_version → $new_version)"
  elif [ -n "$old_version" ]; then
    echo "Updated: $plugin_name ($old_version)"
  else
    echo "Updated: $plugin_name"
  fi
}

# Update all installed plugins
update_all() {
  local pdir
  pdir=$(get_plugin_dir_ex)
  
  if [ ! -d "$pdir" ]; then
    echo "No plugin directory"
    return 1
  fi
  
  for plugin_path in "$pdir"*; do
    [ -d "$plugin_path/.git" ] || continue
    
    local plugin_name
    plugin_name=$(basename "$plugin_path")
    update_single "$plugin_name"
  done
}

# Main
main() {
  local target="${1:-}"
  
  if [ "$target" = "all" ]; then
    update_all
  elif [ -n "$target" ]; then
    update_single "$target"
  else
    echo "Usage: $0 <plugin>|all"
    echo "  plugin  - Update specific plugin"
    echo "  all     - Update all installed plugins"
    exit 1
  fi
}

main "$@"