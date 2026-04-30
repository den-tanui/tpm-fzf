#!/usr/bin/env bash

# Validate a plugin URL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# Validate a plugin URL
validate_plugin() {
  local url="$1"
  
  # Extract author/repo
  local repo
  repo=$(echo "$url" | sed 's|.*github.com/||' | sed 's|\.git$||')
  
  if [ -z "$repo" ]; then
    echo "Invalid URL: empty"
    return 1
  fi
  
  # Try to check if .tmux file exists
  local tmux_url="https://raw.githubusercontent.com/${repo}/master/.tmux"
  local readme_url="https://raw.githubusercontent.com/${repo}/master/README.md"
  
  # Check .tmux file
  if curl -s --max-time 10 -I "$tmux_url" 2>/dev/null | grep -q "200"; then
    echo "valid"
    return 0
  fi
  
  # Check README as fallback
  if curl -s --max-time 10 -I "$readme_url" 2>/dev/null | grep -q "200"; then
    echo "valid (README only)"
    return 0
  fi
  
  echo "invalid"
  return 1
}

# Quick validation (shorter timeout)
validate_plugin_quick() {
  local url="$1"
  
  local repo
  repo=$(echo "$url" | sed 's|.*github.com/||' | sed 's|\.git$||')
  
  if [ -z "$repo" ]; then
    return 1
  fi
  
  # Quick check for repo existence
  if curl -s --max-time 5 -I "https://github.com/${repo}" 2>/dev/null | grep -q "200"; then
    echo "valid"
    return 0
  fi
  
  echo "invalid"
  return 1
}

# Main
main() {
  local url="${1:-}"
  
  if [ -z "$url" ]; then
    echo "Usage: $0 <plugin-url>"
    exit 1
  fi
  
  local quick="${2:-}"
  
  if [ "$quick" = "quick" ]; then
    validate_plugin_quick "$url"
  else
    validate_plugin "$url"
  fi
}

main "$@"