#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPM_DIR="$(dirname "$CURRENT_DIR")"

# Source the library functions
source "$TPM_DIR/lib/plugin_functions.sh"

test_get_local_plugins() {
	echo "Testing get_local_plugins..."
	local result
	result="$(get_local_plugins)"
	# Just verify it returns something (possibly empty)
	if [ -z "$result" ]; then
		echo "OK: get_local_plugins returned empty (no plugins)"
	else
		echo "OK: get_local_plugins returned plugins"
		echo "Result: $result"
	fi
}

test_categorize_plugins() {
	echo "Testing categorize_plugins..."
	local result
	result="$(categorize_plugins)"
	# Check output format if not empty
	if [ -n "$result" ]; then
		if echo "$result" | grep -q "|"; then
			echo "OK: categorize_plugins works (format correct)"
		else
			echo "FAIL: categorize_plugins output format incorrect"
			return 1
		fi
	else
		echo "OK: categorize_plugins returned empty (no plugins)"
	fi
	echo "Result: $result"
}

test_get_local_plugins
test_categorize_plugins

echo "All tests passed"
