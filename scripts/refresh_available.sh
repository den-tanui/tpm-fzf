#!/usr/bin/env bash
# Script to refresh the available plugins cache

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$CURRENT_DIR")/lib"

source "$LIB_DIR/plugin_functions.sh"

refresh_available_plugins_cache
echo "Available plugins cache refreshed"
