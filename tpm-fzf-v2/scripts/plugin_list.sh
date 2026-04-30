#!/usr/bin/env bash

# Main fzf interface for tpm_fzf_v2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=scripts/variables.sh
source "${SCRIPT_DIR}/scripts/variables.sh"
# shellcheck source=scripts/parse_tmux_conf.sh
source "${SCRIPT_DIR}/scripts/parse_tmux_conf.sh"
# shellcheck source=scripts/messaging.sh
source "${SCRIPT_DIR}/scripts/messaging.sh"

get_plugin_dir_ex() {
  local pdir
  pdir=$(get_plugin_dir)
  echo "${pdir/~/$HOME}"
}

# Main execution
main() {
  # Check if --list flag is provided for debugging
  if [ "$1" = "--list" ]; then
    "${SCRIPT_DIR}/scripts/build_fzf_list.sh"
    return
  fi
  
  # Get popup dimensions
  local popup_w=$(get_popup_w)
  local popup_h=$(get_popup_h)
  
  # Run fzf with dynamic footer like APF
  "${SCRIPT_DIR}/scripts/build_fzf_list.sh" | \
    fzf --ansi \
        --reverse \
        --header="TPM FZF Plugin Manager" \
        --header-lines=3 \
        --bind="ctrl-h:execute(echo 'Help: Alt+I=install, Alt+U=update, Alt+D=remove, Alt+C=clean, Alt+S=source, Alt+R=reload, Tab=multi-select')+abort" \
        --bind="alt-i:execute-silent(${SCRIPT_DIR}/scripts/plugin_install.sh {2})+reload(${SCRIPT_DIR}/scripts/plugin_list.sh)" \
        --bind="alt-u:execute-silent(${SCRIPT_DIR}/scripts/plugin_update.sh {2})+reload(${SCRIPT_DIR}/scripts/plugin_list.sh)" \
        --bind="alt-d:execute-silent(${SCRIPT_DIR}/scripts/plugin_remove.sh {2})+reload(${SCRIPT_DIR}/scripts/plugin_list.sh)" \
        --bind="alt-c:execute-silent(${SCRIPT_DIR}/scripts/plugin_clean.sh)+reload(${SCRIPT_DIR}/scripts/plugin_list.sh)" \
        --bind="alt-s:execute-silent(${SCRIPT_DIR}/scripts/plugin_source.sh)+reload(${SCRIPT_DIR}/scripts/plugin_list.sh)" \
        --bind="alt-r:reload(${SCRIPT_DIR}/scripts/plugin_list.sh)" \
        --bind="tab:toggle+down" \
        --bind="shift-tab:toggle+up" \
        --preview="${SCRIPT_DIR}/scripts/plugin_preview.sh {2}" \
        --preview-window=right:60%:wrap \
        --expect=enter \
        --color="fg:-1,bg:-1,hl:#ffff00,fg+:#ffffff,bg+:#000000,hl+:#ffff00" \
        --prompt="Plugins> " \
        --margin=0,0,0,0
}

# Handle fzf output
handle_output() {
  # Read all output from fzf
  local output
  output=$(cat)
  
  # Extract key (first line) and selection (second line)
  local key
  local selection
  key=$(echo "$output" | head -n1)
  selection=$(echo "$output" | head -n2 | tail -n1)
  
  case "$key" in
    enter)
      # Enter pressed - just exit
      ;;
  esac
  
  # Process selection if not empty
  if [ -n "$selection" ] && [ "$selection" != "" ] && [ "$selection" != " " ]; then
    # Remove ANSI codes and get plugin name (last column)
    local plugin
    plugin=$(echo "$selection" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $NF}')
    
    # Determine action based on category prefix
    if echo "$selection" | grep -q "\[installed\]"; then
      "${SCRIPT_DIR}/scripts/plugin_remove.sh" "$plugin"
    elif echo "$selection" | grep -q "\[available\]" || echo "$selection" | grep -q "\[pending\]"; then
      "${SCRIPT_DIR}/scripts/plugin_install.sh" "$plugin"
    elif echo "$selection" | grep -q "\[orphaned\]"; then
      "${SCRIPT_DIR}/scripts/plugin_clean.sh" "$plugin"
    fi
    
    # Reload list after action
    "${SCRIPT_DIR}/scripts/plugin_list.sh" >/dev/null 2>&1
  fi
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@" | handle_output
fi