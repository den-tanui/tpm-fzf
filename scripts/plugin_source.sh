#!/usr/bin/env bash
# Script to source TPM plugins (sources *.tmux files from all plugins)
# Also installs any pending plugins via bin/install_plugins

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${YELLOW}Sourcing TPM plugins...${RESET}"

# Run source_plugins.sh which sources all *.tmux files from plugins
cd "$CURRENT_DIR" && bash source_plugins.sh

# Check exit status
if [ $? -eq 0 ]; then
	echo -e "${GREEN}Plugins sourced successfully${RESET}"
else
	echo -e "${RED}Failed to source plugins${RESET}"
fi
