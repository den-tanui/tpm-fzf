#!/usr/bin/env bash

# Messaging utilities for tpm_fzf_v2

# Display message via tmux
msg() {
  local message="$1"
  tmux display-message -p "$message" 2>/dev/null
}

# Display error message
msg_error() {
  local message="$1"
  tmux display-message -p "#[fg=red]Error: $message" 2>/dev/null
}

# Display success message
msg_success() {
  local message="$1"
  tmux display-message -p "#[fg=green]$message" 2>/dev/null
}

# Display info message
msg_info() {
  local message="$1"
  tmux display-message -p "#[fg=blue]$message" 2>/dev/null
}

# Ask user for input via tmux
ask() {
  local prompt="$1"
  local default="$2"
  tmux command-prompt -p "$prompt" "run-shell 'echo %%'" 2>/dev/null
}

# Alternative: echo for shell output
shell_msg() {
  local message="$1"
  echo "$message"
}

shell_error() {
  local message="$1"
  echo "[ERROR] $message" >&2
}

shell_success() {
  local message="$1"
  echo "[OK] $message"
}

# Main when sourced directly
main() {
  local action="${1:-msg}"
  shift
  
  case "$action" in
    msg)
      msg "$1"
      ;;
    error)
      msg_error "$1"
      ;;
    success)
      msg_success "$1"
      ;;
    info)
      msg_info "$1"
      ;;
    shell-msg)
      shell_msg "$1"
      ;;
    shell-error)
      shell_error "$1"
      ;;
    shell-success)
      shell_success "$1"
      ;;
    *)
      echo "Usage: $0 {msg|error|success|info|shell-msg|shell-error|shell-success} <message>"
      ;;
  esac
}

# Run main if executed
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi