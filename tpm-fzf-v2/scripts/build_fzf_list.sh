#!/usr/bin/env bash

# Build the fzf list with categories for tpm_fzf_v2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=scripts/variables.sh
source "${SCRIPT_DIR}/scripts/variables.sh"
# shellcheck source=scripts/parse_tmux_conf.sh
source "${SCRIPT_DIR}/scripts/parse_tmux_conf.sh"
# shellcheck source=../lib/plugin_functions.sh
source "${SCRIPT_DIR}/../lib/plugin_functions.sh"
# shellcheck source=scripts/messaging.sh
source "${SCRIPT_DIR}/scripts/messaging.sh"
# shellcheck source=scripts/check_online.sh
source "${SCRIPT_DIR}/scripts/check_online.sh"
# shellcheck source=scripts/validate_plugin.sh
source "${SCRIPT_DIR}/scripts/validate_plugin.sh"

get_plugin_dir_ex() {
  local pdir
  pdir=$(get_plugin_dir)
  echo "${pdir/~/$HOME}"
}

# Build list with category headers
build_list() {
  local pdir
  pdir=$(get_plugin_dir_ex)
  
  # Get installed plugins
  local installed
  installed=$(get_installed_plugins 2>/dev/null)
  
  # Get plugins from tmux.conf (wanted)
  local wanted
  wanted=$(get_plugins_between_markers)
  
  # Get available plugins from config
  local available
  available=$(get_available_plugins 2>/dev/null || echo "")
  
  # Check online status
  local online_status
  online_status=$(check_online_quick)
  
  # Output with category headers
  {
    # Pending: in tmux.conf but not installed
    echo "[pending]"
    while IFS= read -r plugin; do
      [ -z "$plugin" ] && continue
      if ! echo "$installed" | grep -q "^${plugin}$"; then
        echo "$plugin"
      fi
    done <<< "$wanted"
    
    # Installed: in tmux.conf AND installed
    echo "[installed]"
    while IFS= read -r plugin; do
      [ -z "$plugin" ] && continue
      if echo "$wanted" | grep -q "^${plugin}$"; then
        echo "$plugin"
      fi
    done <<< "$installed"
    
    # Orphaned: installed but not in tmux.conf
    echo "[orphaned]"
    while IFS= read -r plugin; do
      [ -z "$plugin" ] && continue
      if ! echo "$wanted" | grep -q "^${plugin}$"; then
        echo "$plugin"
      fi
    done <<< "$installed"
    
    # Available: from config, not in above, and valid (if online)
    echo "[available]"
    if [ "$online_status" = "online" ]; then
      while IFS= read -r url; do
        [ -z "$url" ] && continue
        [[ "$url" =~ ^# ]] && continue
        
        local plugin
        plugin=$(echo "$url" | sed 's|.*github.com/||' | sed 's|\.git$||')
        
        # Skip if in any other category
        if ! echo "$pending$installed$orphaned" | grep -q "^${plugin}$"; then
          # Validate plugin (check .tmux or README)
          if "${SCRIPT_DIR}/scripts/validate_plugin.sh" "$url" quick | grep -q "valid"; then
            echo "$plugin"
          fi
        fi
      done < "$(get_plugins_config)"
    fi
  }
}

# Main
main() {
  build_list
}

main "$@"