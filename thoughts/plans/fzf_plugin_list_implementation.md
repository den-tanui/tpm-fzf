# fzf Popup Interface for TPM Plugin List

## Overview

Implement an interactive fzf-based popup interface for TPM (Tmux Plugin Manager) that displays local plugins with three categories: Pending (auto-install), Installed, and Orphaned. The feature replaces the current `prefix + I` workflow with a searchable, fuzzy-finding interface.

## Current State Analysis

**What exists now:**
- `bindings/install_plugins` - Simple key binding that triggers installation
- `scripts/install_plugins.sh` - Installs plugins from tmux.conf
- `scripts/clean_plugins.sh` - Removes orphaned plugins
- `scripts/helpers/plugin_functions.sh` - Core functions: `tpm_plugins_list_helper()`, `plugin_already_installed()`, `plugin_path_helper()`

**What's missing:**
- No interactive plugin browser/selector
- No fuzzy search capability
- No visualization of plugin status (pending/installed/orphaned)
- No preview functionality

**Key constraints discovered:**
- Must work within existing TPM architecture
- Uses tmux 2.9+ popup feature (`display-popup`)
- Requires fzf as dependency
- Must source existing helper functions for plugin detection

## Desired End State

After implementation:
1. Press `prefix + I` opens an fzf popup showing all plugins
2. Three categories displayed with status indicators:
   - **Pending** - in tmux.conf but not installed (auto-installed on open)
   - **Installed** - in both tmux.conf and plugin dir
   - **Orphaned** - in plugin dir but not in tmux.conf
3. Fuzzy search filters plugins by name
4. Preview window shows README and install status
5. Multi-select support for batch operations
6. Orphaned plugins can be removed with confirmation

### Key Discoveries:
- `scripts/helpers/plugin_functions.sh:71-78` - `tpm_plugins_list_helper()` parses tmux.conf for @plugin entries
- `scripts/helpers/plugin_functions.sh:98-103` - `plugin_already_installed()` checks if plugin dir exists and is a git repo
- `scripts/clean_plugins.sh:15-34` - Logic for detecting orphaned plugins (directory exists but not in tmux.conf)
- `tmux display-popup -E` pattern from tmux-session-manager provides template for popup + fzf integration

## What We're NOT Doing

- **Remote plugin repository**: Showing available TPM plugins from github.com/tmux-plugins/list is out of scope
- **Plugin browser beyond local**: No integration with remote plugin discovery
- **Adding new dependencies beyond fzf**: Using existing bash/awk tools only
- **Persistent configuration**: No TPM configuration options for this feature initially

## Implementation Approach

Use a modular approach:
1. Create new helper functions for plugin list generation
2. Create main script that orchestrates auto-install + popup display
3. Replace existing binding to use new functionality
4. Follow existing TPM patterns for sourcing and error handling

## Phase 1: Plugin Detection Functions

### Overview
Add functions to detect and categorize plugins into three states.

### Changes Required:

#### 1. New helper functions
**File**: `scripts/helpers/plugin_functions.sh`
**Changes**: Add new functions at end of file

```bash
# Get list of all plugins in plugin directory (regardless of tmux.conf)
get_local_plugins() {
    local plugin_dir
    for plugin_dir in "$(tpm_path)"/*; do
        [ -d "${plugin_dir}" ] || continue
        plugin="$(plugin_name_helper "${plugin_dir}")"
        [ "${plugin}" = "tpm" ] && continue
        echo "${plugin}"
    done
}

# Categorize plugins into pending/installed/orphaned
# Output format: status|plugin_name|plugin_path
categorize_plugins() {
    local plugins plugin plugin_path installed_plugins
    plugins="$(tpm_plugins_list_helper)"
    installed_plugins="$(get_local_plugins)"
    
    # Check each plugin in tmux.conf
    for plugin in $plugins; do
        if plugin_already_installed "$plugin"; then
            echo "installed|${plugin}|$(plugin_path_helper "$plugin")"
        else
            echo "pending|${plugin}|$(plugin_path_helper "$plugin")"
        fi
    done
    
    # Find orphaned plugins (in dir but not in tmux.conf)
    for plugin in $installed_plugins; do
        case "${plugins}" in
            *"${plugin}"*) : ;;
            *) echo "orphaned|${plugin}|$(tpm_path)${plugin}/" ;;
        esac
    done
}
```

### Success Criteria:

#### Automated Verification:
- [ ] New functions can be sourced without errors: `source scripts/helpers/plugin_functions.sh`
- [ ] `get_local_plugins` returns list of plugin directories
- [ ] `categorize_plugins` correctly identifies all three states

#### Manual Verification:
- [ ] Run in tmux with TPM configured - functions return correct plugin states

---

## Phase 2: Plugin List Display Script

### Overview
Create the main script that generates the plugin list for fzf, handles auto-install, and displays the popup.

### Changes Required:

#### 1. New plugin list script
**File**: `scripts/plugin_list.sh`
**Changes**: Create new file

```bash
#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS_DIR="$CURRENT_DIR/helpers"

source "$HELPERS_DIR/plugin_functions.sh"
source "$HELPERS_DIR/utility.sh"

# Check for fzf dependency
check_fzf() {
    if ! command -v fzf &> /dev/null; then
        echo "Error: fzf is not installed" >&2
        echo "Please install fzf: https://github.com/junegunn/fzf" >&2
        exit 1
    fi
}

# Auto-install pending plugins
auto_install_pending() {
    local plugins plugin
    plugins="$(tpm_plugins_list_helper)"
    
    for plugin in $plugins; do
        if ! plugin_already_installed "$plugin"; then
            # Install plugin (reuse logic from install_plugins.sh)
            local plugin_name="$(plugin_name_helper "$plugin")"
            echo "Installing pending plugin: $plugin_name"
            cd "$(tpm_path)" && GIT_TERMINAL_PROMPT=0 git clone --single-branch --recursive "$plugin" >/dev/null 2>&1
        fi
    done
}

# Generate plugin list for fzf
generate_plugin_list() {
    categorize_plugins | while IFS='|' read -r status name path; do
        case "$status" in
            pending)   echo "[pending]  $name" ;;
            installed) echo "[installed] $name" ;;
            orphaned)  echo "[orphaned] $name" ;;
        esac
    done
}

# Generate preview for a plugin
generate_preview() {
    local selection="$1"
    # Extract plugin name from selection
    local plugin_name="$(echo "$selection" | sed 's/.*]  *//')"
    local status="$(echo "$selection" | sed 's/\[.*\].*/\1' | tr -d ' ')"
    local plugin_path="$(plugin_path_helper "$plugin_name")"
    
    echo "Plugin: $plugin_name"
    echo "Status: $status"
    echo "Path: $plugin_path"
    echo ""
    
    # Try to show README if exists
    if [ -f "${plugin_path}README.md" ]; then
        echo "--- README ---"
        head -50 "${plugin_path}README.md"
    elif [ -f "${plugin_path}readme.md" ]; then
        echo "--- README ---"
        head -50 "${plugin_path}readme.md"
    else
        echo "(No README found)"
    fi
}

# Main execution
main() {
    check_fzf
    
    # Auto-install pending plugins first
    auto_install_pending
    
    # Generate list and run fzf
    local selection
    selection=$(generate_plugin_list | \
        fzf --preview="generate_preview {}" \
            --preview-window="right:50%" \
            --prompt="Search plugins> " \
            --header="[pending] = new | [installed] = working | [orphaned] = cleanup | Enter: refresh | Ctrl-D: delete orphaned" \
            --bind="ctrl-r:reload(categorize_plugins | ...)" \
            --bind="ctrl-d:execute(echo {q} is orphaned)" \
            --multi)
    
    # Handle selection
    if [ -n "$selection" ]; then
        # Process selected plugins
        echo "Selected: $selection"
    fi
}

main "$@"
```

### Success Criteria:

#### Automated Verification:
- [ ] Script runs without syntax errors
- [ ] `check_fzf` correctly detects missing fzf

#### Manual Verification:
- [ ] Script generates correct plugin list
- [ ] Preview shows README and status

---

## Phase 3: Key Binding Integration

### Overview
Replace the existing `bindings/install_plugins` to use the new plugin list popup.

### Changes Required:

#### 1. Update key binding
**File**: `bindings/install_plugins`
**Changes**: Replace content

```bash
#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTS_DIR="$CURRENT_DIR/../scripts"
HELPERS_DIR="$SCRIPTS_DIR/helpers"

source "$HELPERS_DIR/tmux_echo_functions.sh"
source "$HELPERS_DIR/tmux_utils.sh"

main() {
    reload_tmux_environment
    
    # Check fzf first
    if ! command -v fzf &> /dev/null; then
        tmux_echo "Error: fzf not installed"
        tmux_echo "Install: https://github.com/junegunn/fzf"
        return 1
    fi
    
    # Run plugin list in tmux popup
    tmux display-popup -E -w 80% -h 70% -T "TPM Plugin List" \
        "cd '$SCRIPTS_DIR' && bash plugin_list.sh"
    
    reload_tmux_environment
}

main
```

### Success Criteria:

#### Automated Verification:
- [ ] Binding script is executable

#### Manual Verification:
- [ ] `prefix + I` opens the fzf popup
- [ ] Popup displays in tmux window
- [ ] Auto-install runs for pending plugins

---

## Phase 4: Enhanced fzf Features

### Overview
Add multi-select, preview improvements, and orphaned plugin deletion.

### Changes Required:

#### 1. Update plugin_list.sh with full features
**File**: `scripts/plugin_list.sh`
**Changes**: Add multi-select and delete handling

```bash
# Handle orphaned plugin deletion with confirmation
delete_orphaned() {
    local plugin_name="$1"
    local plugin_path="$(tpm_path)${plugin_name}/"
    
    echo ""
    echo "Delete orphaned plugin: $plugin_name ?"
    echo "This will remove: $plugin_path"
    read -p "Type 'yes' to confirm: " confirm
    
    if [ "$confirm" = "yes" ]; then
        rm -rf "$plugin_path"
        echo "Deleted: $plugin_name"
    else
        echo "Cancelled"
    fi
}

# Main fzf with full features
main() {
    check_fzf
    auto_install_pending
    
    # Multi-select enabled, Ctrl-D to delete orphaned
    local result
    result=$(categorize_plugins | awk -F'|' '{print "["$1"]  " $2}' | \
        fzf --multi \
            --preview="$0 _preview {}" \
            --preview-window="right:50%:wrap" \
            --prompt="Search> " \
            --header=" ENTER=install/refresh | CTRL-D=delete orphaned | ESC=quit" \
            --bind="enter:execute($0 _handle {+})" \
            --bind="ctrl-d:execute($0 _delete {+})" \
            --bind="ctrl-r:reload($0 _list)" \
            --肥span>0)
}

# Preview handler
_preview() {
    local selection="$1"
    # Same as generate_preview
}

# Delete handler
_delete() {
    for item in "$@"; do
        if [[ "$item" == *"[orphaned]"* ]]; then
            local name=$(echo "$item" | sed 's/.*]  //')
            delete_orphaned "$name"
        fi
    done
}

# List generator
_list() {
    categorize_plugins | awk -F'|' '{print "["$1"]  " $2}'
}
```

### Success Criteria:

#### Automated Verification:
- [ ] Multi-select works with --multi flag
- [ ] Ctrl-D triggers delete for orphaned plugins

#### Manual Verification:
- [ ] Can select multiple plugins
- [ ] Delete confirmation works
- [ ] Refresh (Ctrl-R) reloads list

---

## Testing Strategy

### Unit Tests:
- Plugin categorization logic (pending/installed/orphaned)
- get_local_plugins returns correct list
- auto_install_pending skips already-installed plugins

### Integration Tests:
- Full flow: open popup → auto-install → browse → select

### Manual Testing Steps:
1. Add new plugin to tmux.conf (not yet installed)
2. Press `prefix + I` - verify pending plugin auto-installs
3. Remove plugin from tmux.conf (keep directory)
4. Press `prefix + I` - verify orphaned shows with cleanup option
5. Test fuzzy search by typing plugin name
6. Test preview window shows README

---

## Performance Considerations

- Auto-install runs on every popup open - could be cached
- Preview reads README files - could be slow for many plugins
- Consider lazy loading preview content

---

## Migration Notes

- This replaces `prefix + I` behavior for plugin installation
- Existing `prefix + U` (update) and `prefix + alt + u` (clean) remain unchanged
- Users without fzf will see error message with install instructions

---

## References

- Original ticket: `thoughts/tickets/feature_fzf_plugin_list.md`
- Related research: `thoughts/research/2026-03-03_fzf_plugin_list.md`
- Existing binding: `bindings/install_plugins:1-19`
- Plugin functions: `scripts/helpers/plugin_functions.sh:71-103`
- Clean logic: `scripts/clean_plugins.sh:15-34`
- Reference implementation: tmux-session-manager (santoshxshrestha)
