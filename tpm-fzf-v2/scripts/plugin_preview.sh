#!/usr/bin/env bash

# Preview script for tpm_fzf_v2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

source "${SCRIPT_DIR}/scripts/variables.sh"

# Get plugin directory
get_plugin_dir_ex() {
  local pdir
  pdir=$(get_plugin_dir)
  echo "${pdir/~/$HOME}"
}

# Preview installed plugin
preview_installed() {
  local plugin="$1"
  local pdir
  pdir=$(get_plugin_dir_ex)
  local plugin_path="${pdir}${plugin}"
  
  if [ ! -d "$plugin_path" ]; then
    echo "Not installed: $plugin"
    return
  fi
  
  # Check for updates
  local has_update=""
  if [ -d "$plugin_path/.git" ]; then
    cd "$plugin_path" || return
    git fetch --all --tags 2>/dev/null
    
    local behind
    behind=$(git rev-list "origin/HEAD..HEAD" --count 2>/dev/null)
    if [ -n "$behind" ] && [ "$behind" -gt 0 ]; then
      has_update=" [Updates available]"
    fi
  fi
  
  echo "#[bold]$plugin#[nobold]$has_update"
  echo ""
  
  # Show README if exists
  local readme
  for readme in README.md README README.txt; do
    if [ -f "$plugin_path/$readme" ]; then
      # Use bat if available, otherwise cat
      if command -v bat &>/dev/null; then
        bat "$plugin_path/$readme" --style=plain --color=always 2>/dev/null | head -50
      else
        head -50 "$plugin_path/$readme"
      fi
      break
    fi
  done
}

# Preview available plugin (from config)
# Note: This would need network access to fetch preview
preview_available() {
  local plugin="$1"
  
  echo "#[bold]$plugin (available)"
  echo ""
  echo "Not yet installed."
  echo "Press #[bold]Alt+I#[nobold] to install"
}

# Main - get plugin from argument or read from FZF
main() {
  local plugin="${1:-}"
  
  if [ -z "$plugin" ]; then
    # Read from stdin (FZF passes selected)
    read -r plugin
  fi
  
  if [ -z "$plugin" ]; then
    echo "No plugin selected"
    exit 0
  fi
  
  # Strip category prefix if present
  plugin="${plugin#*] }"
  
  # Check if installed
  local pdir
  pdir=$(get_plugin_dir_ex)
  
  if [ -d "${pdir}${plugin}" ]; then
    preview_installed "$plugin"
  else
    preview_available "$plugin"
  fi
}

main "$@"