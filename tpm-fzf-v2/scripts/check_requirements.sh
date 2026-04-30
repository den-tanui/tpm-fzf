#!/usr/bin/env bash

# Check requirements for tpm_fzf_v2

SUPPORTED_TMUX_VERSION="2.17"

# Check tmux version
check_tmux_version() {
  local required="$1"
  local version
  version=$(tmux -V 2>/dev/null | sed 's/tmux //' | cut -d. -f1-2)
  
  if [ -z "$version" ]; then
    echo "Tmux not found"
    return 1
  fi
  
  # Simple comparison (major.minor)
  if [ "$(printf '%s\n' "$required" "$version" | sort -V | head -n1)" != "$required" ]; then
    echo "Tmux version $version (required: $required+)"
    return 1
  fi
  
  echo "OK"
}

# Check required commands
check_commands() {
  local missing=""
  local required_commands="fzf git curl"
  
  for cmd in $required_commands; do
    if ! command -v "$cmd" &>/dev/null; then
      missing="$missing $cmd"
    fi
  done
  
  if [ -n "$missing" ]; then
    echo "Missing:$missing"
    return 1
  fi
  
  echo "OK"
}

# Check for preview tool (bat or cat)
check_preview_tool() {
  if command -v bat &>/dev/null; then
    echo "bat"
  elif command -v cat &>/dev/null; then
    echo "cat"
  else
    echo "None"
    return 1
  fi
}

# Run all checks
check_all() {
  local errors=0
  
  echo "Checking requirements..."
  
  # Check tmux
  if ! check_tmux_version "$SUPPORTED_TMUX_VERSION" >/dev/null; then
    echo "  [FAIL] Tmux version"
    errors=$((errors + 1))
  else
    echo "  [PASS] Tmux version"
  fi
  
  # Check commands
  if ! check_commands >/dev/null; then
    echo "  [FAIL] Required commands"
    errors=$((errors + 1))
  else
    echo "  [PASS] Required commands"
  fi
  
  # Check preview
  if check_preview_tool >/dev/null; then
    echo "  [PASS] Preview tool"
  else
    echo "  [WARN] Preview tool (bat suggested)"
  fi
  
  if [ $errors -gt 0 ]; then
    echo "Failed: $errors check(s)"
    return 1
  fi
  
  echo "All checks passed"
}

# Main
main() {
  local check="${1:-all}"
  
  case "$check" in
    tmux)
      check_tmux_version "$SUPPORTED_TMUX_VERSION"
      ;;
    commands)
      check_commands
      ;;
    preview)
      check_preview_tool
      ;;
    all)
      check_all
      ;;
    *)
      echo "Usage: $0 {tmux|commands|preview|all}"
      exit 1
      ;;
  esac
}

main "$@"