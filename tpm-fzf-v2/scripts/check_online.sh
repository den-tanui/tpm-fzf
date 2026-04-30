#!/usr/bin/env bash

# Check if GitHub is reachable

# Check online status (non-blocking)
check_online() {
  # Try to reach github.com
  if curl -s --max-time 3 -I https://github.com >/dev/null 2>&1; then
    echo "online"
  else
    echo "offline"
  fi
}

# Quick check (shorter timeout)
check_online_quick() {
  if curl -s --max-time 1 -I https://github.com >/dev/null 2>&1; then
    echo "online"
  else
    echo "offline"
  fi
}

# Main when executed
main() {
  local quick="${1:-}"
  
  if [ "$quick" = "quick" ]; then
    check_online_quick
  else
    check_online
  fi
}

main "$@"