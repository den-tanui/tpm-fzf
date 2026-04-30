#!/usr/bin/env bash

# Install plugin(s) for tpm_fzf_v2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=scripts/variables.sh
source "${SCRIPT_DIR}/scripts/variables.sh"
# shellcheck source=scripts/parse_tmux_conf.sh
source "${SCRIPT_DIR}/scripts/parse_tmux_conf.sh"

# Get plugin directory
get_plugin_dir_ex() {
  local pdir
  pdir=$(get_plugin_dir)
  echo "${pdir/~/$HOME}"
}

# Clone a single plugin
clone_plugin() {
  local plugin="$1"
  local pdir
  pdir=$(get_plugin_dir_ex)
  
  # Ensure directory exists
  [ -d "$pdir" ] || mkdir -p "$pdir"
  
  local plugin_name
  plugin_name=$(basename "$plugin")
  
  # Check if already installed
  if [ -d "${pdir}${plugin_name}" ]; then
    echo "Plugin $plugin_name already installed"
    return 0
  fi
  
  # Try git clone first, then gh if available
  local git_cmd
  git_cmd=$(get_git_command)
  
  cd "$pdir" || return 1
  
  if [ "$git_cmd" = "gh repo clone" ] && command -v gh &>/dev/null; then
    gh repo clone "$plugin" "${pdir}${plugin_name}" -- --source --single-branch 2>/dev/null
  else
    GIT_TERMINAL_PROMPT=0 git clone "https://github.com/${plugin}.git" "${pdir}${plugin_name}" --single-branch 2>/dev/null
  fi
  
  if [ -d "${pdir}${plugin_name}" ]; then
    echo "Installed: $plugin_name"
    return 0
  else
    echo "Failed to install: $plugin_name"
    return 1
  fi
}

# Install a single plugin (add to tmux.conf + clone)
install_single() {
  local plugin="$1"
  
  # Add to tmux.conf
  add_plugin "$plugin"
  
  # Clone the repo
  clone_plugin "$plugin"
}

# Install all plugins from tmux.conf that aren't cloned yet
install_all() {
  local pdir
  pdir=$(get_plugin_dir_ex)
  
  # Get plugins from tmux.conf (the ones we want)
  local plugins
  plugins=$(get_plugins_between_markers)
  
  if [ -z "$plugins" ]; then
    echo "No plugins in tmux.conf"
    return 1
  fi
  
  while IFS= read -r plugin; do
    [ -z "$plugin" ] && continue
    
    # Check if already cloned
    if [ -d "${pdir}${plugin}" ]; then
      echo "Already installed: $plugin"
      continue
    fi
    
    # Install
    echo "Installing $plugin..."
    clone_plugin "$plugin"
    
  done <<< "$plugins"
}

# Main
main() {
  local target="${1:-}"
  
  if [ "$target" = "all" ]; then
    install_all
  elif [ -n "$target" ]; then
    install_single "$target"
  else
    echo "Usage: $0 <plugin>|all"
    echo "  plugin  - Install specific plugin (e.g., tmux-plugins/tpm)"
    echo "  all    - Install all plugins from plugins.conf"
    exit 1
  fi
}

main "$@"