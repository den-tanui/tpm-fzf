#!/usr/bin/env bash

# Parse tmux.conf for @plugin lines and manage plugin markers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=scripts/variables.sh
source "${SCRIPT_DIR}/scripts/variables.sh"

MARKER_START="#TPM plugins"
MARKER_END="#End of Plugins"

# Get tmux.conf path
get_conf() {
  get_tmux_conf
}

# Check if markers exist
has_markers() {
  local conf
  conf=$(get_conf)
  grep -q "$MARKER_START" "$conf" 2>/dev/null && \
  grep -q "$MARKER_END" "$conf" 2>/dev/null
}

# Ensure markers exist in tmux.conf
ensure_markers() {
  local conf
  conf=$(get_conf)
  
  if ! has_markers; then
    # Add markers at end of file (before any run-shell)
    if [ -f "$conf" ]; then
      local backup
      backup="${conf}.bak"
      cp "$conf" "$backup"
      
      # Create new file with markers
      {
        echo ""
        echo "$MARKER_START"
        echo "# Add your plugins between these markers"
        echo "$MARKER_END"
        echo ""
        # Try to add source line
        local plugin_dir
        plugin_dir=$(get_plugin_dir)
        echo "run-shell \"${plugin_dir}tpm-fzf-v2/scripts/plugin_source.sh\""
      } >> "$conf"
    else
      # Create new conf with markers
      {
        echo "$MARKER_START"
        echo "# Add your plugins between these markers"
        echo "$MARKER_END"
        echo ""
        local plugin_dir
        plugin_dir=$(get_plugin_dir)
        echo "run-shell \"${plugin_dir}tpm-fzf-v2/scripts/plugin_source.sh\""
      } > "$conf"
    fi
  fi
}

# Get plugins between markers
get_plugins_between_markers() {
  local conf
  conf=$(get_conf)
  local in_block=0
  local plugins=""
  
  while IFS= read -r line; do
    if [ "$line" = "$MARKER_START" ]; then
      in_block=1
    elif [ "$line" = "$MARKER_END" ]; then
      in_block=0
    elif [ $in_block -eq 1 ]; then
      # Extract plugin name from @plugin line
      local plugin
      plugin=$(echo "$line" | sed -E 's/.*@plugin[[:space:]]+["'\'']([^"'\'']+)["'\''].*/\1/')
      if [ -n "$plugin" ] && [ "$plugin" != "$line" ]; then
        # Skip commented lines
        if [[ ! "$line" =~ ^[[:space:]]*# ]]; then
          echo "$plugin"
        fi
      fi
    fi
  done < "$conf" | sort -u
}

# Get all @plugin lines (including commented)
get_all_plugins() {
  local conf
  conf=$(get_conf)
  
  grep -E '^[[:space:]]*#?[[:space:]]*set[[:space:]]+-g[[:space:]]+@plugin' "$conf" 2>/dev/null | \
    sed -E 's/.*@plugin[[:space:]]+["'\'']([^"'\'']+)["'\''].*/\1/' | \
    sort -u
}

# Check if plugin is in tmux.conf (active)
plugin_in_conf() {
  local plugin="$1"
  local conf
  conf=$(get_conf)
  grep -q "@plugin.*['\'']${plugin}['\'']" "$conf" 2>/dev/null
}

# Check if plugin is commented out
plugin_commented() {
  local plugin="$1"
  local conf
  conf=$(get_conf)
  grep -E "^[[:space:]]*#.*@plugin.*['\'']${plugin}['\'']" "$conf" 2>/dev/null
}

# Add plugin between markers
add_plugin() {
  local plugin="$1"
  local conf
  conf=$(get_conf)
  
  # Check if already exists
  if plugin_in_conf "$plugin"; then
    return 0
  fi
  
  # Ensure markers exist
  ensure_markers
  
  # Insert before #End of Plugins
  local tmp
  tmp=$(mktemp)
  
  local in_block=0
  while IFS= read -r line; do
    if [ "$line" = "$MARKER_END" ]; then
      echo "set -g @plugin \"$plugin\"" >> "$tmp"
      in_block=0
    elif [ "$line" = "$MARKER_START" ]; then
      in_block=1
    fi
    echo "$line" >> "$tmp"
  done < "$conf"
  
  mv "$tmp" "$conf"
}

# Comment out plugin
remove_plugin() {
  local plugin="$1"
  local conf
  conf=$(get_conf)
  
  local tmp
  tmp=$(mktemp)
  
  while IFS= read -r line; do
    if echo "$line" | grep -q "@plugin.*['\'']${plugin}['\'']"; then
      # Comment out but keep the line
      echo "# $line" >> "$tmp"
    else
      echo "$line" >> "$tmp"
    fi
  done < "$conf"
  
  mv "$tmp" "$conf"
}

# Uncomment plugin (restore)
restore_plugin() {
  local plugin="$1"
  local conf
  conf=$(get_conf)
  
  local tmp
  tmp=$(mktemp)
  
  while IFS= read -r line; do
    if echo "$line" | grep -q "^#.*@plugin.*['\'']${plugin}['\'']"; then
      # Remove the leading #
      echo "${line#\#}" >> "$tmp"
    else
      echo "$line" >> "$tmp"
    fi
  done < "$conf"
  
  mv "$tmp" "$conf"
}

# Main when sourced directly
main() {
  local action="${1:-list}"
  
  case "$action" in
    list)
      get_plugins_between_markers
      ;;
    list-all)
      get_all_plugins
      ;;
    add)
      add_plugin "$2"
      ;;
    remove)
      remove_plugin "$2"
      ;;
    restore)
      restore_plugin "$2"
      ;;
    ensure)
      ensure_markers
      ;;
    *)
      echo "Usage: $0 {list|list-all|add|remove|restore|ensure}"
      ;;
  esac
}

# Run main if executed
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi