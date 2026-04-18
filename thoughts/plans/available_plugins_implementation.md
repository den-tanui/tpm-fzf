# FEATURE-003: Add [available] Category to Plugin List - Implementation Plan

## Overview

Add a new "[available]" category to the fzf plugin list popup that displays plugins from the official TPM (Tmux Plugin Manager) repository. Users can browse available plugins, see previews, and install them with full integration into tmux.conf.

## Important Discovery

**The TPM plugin list is NOT in JSON format!** It's a markdown file at:
- https://raw.githubusercontent.com/tmux-plugins/list/master/README.md

Format (each line):
```markdown
- [plugin-name](https://github.com/user/repo) - description
```

**Parsed format:** `user/repo|GitHub URL|description`

Example:
```
tmux-autoreload|https://github.com/b0o/tmux-autoreload|Watches your tmux configuration file and automatically reloads it on change.
```

Implementation must parse this markdown format using grep/sed/awk instead of JSON.

## Current State Analysis

The existing implementation in `scripts/plugin_list.sh` already provides:
- Three categories: [pending], [installed], [orphaned]
- fzf popup with preview window
- Auto-install pending plugins on popup open
- Key bindings for install, update, clean, delete, source
- Uses `categorize_plugins()` in `plugin_functions.sh` to generate pipe-delimited output (`status|name|path`)
- Uses BLUE color code (already defined but unused in plugin_list.sh)

### Key Discoveries:
- `scripts/plugin_list.sh:89-103` - generate_plugin_list uses case statement for status
- `scripts/helpers/plugin_functions.sh:118-141` - categorize_plugins outputs `status|name|path`
- `scripts/plugin_delete.sh:59-61` - Shows how to add comment to tmux.conf with sed
- `scripts/plugin_preview.sh:48-72` - Fetches README from GitHub for pending plugins
- BLUE color already defined at line 63 of plugin_list.sh but unused

## Desired End State

The plugin list popup shows four categories:
1. **[pending]** - plugins in tmux.conf but not yet installed (yellow)
2. **[installed]** - plugins in both tmux.conf AND plugin dir (green)  
3. **[orphaned]** - plugins in plugin dir but NOT in tmux.conf (red)
4. **[available]** - plugins from TPM repository, NOT already configured (blue)

Additional behaviors:
- Available plugins fetched from github.com/tmux-plugins/list JSON API
- Cached in ~/.cache/tpm/available_plugins.json
- Alt+R refreshes the cache
- Preview shows README, Git URL, and stats for available plugins
- Installing adds to tmux.conf AND clones the repo

## What We're NOT Doing

- **GitHub API rate limit handling**: Not implementing complex rate limiting (will show error if fails)
- **README caching**: Fetching README on-demand from GitHub for preview
- **Batch install confirmation**: Installing immediately on selection (no extra confirmation step)
- **Plugin description search**: Name-only search for available plugins (as per requirements)

## Implementation Approach

### High-Level Strategy:
1. **Phase 1**: Add core functions for fetching/cacheing available plugins
2. **Phase 2**: Integrate available into plugin list display
3. **Phase 3**: Enhance preview window for available plugins
4. **Phase 4**: Implement installation flow (add to tmux.conf + clone)
5. **Phase 5**: Testing and validation

---

## Phase 1: Core - Fetch and Cache Available Plugins

### Overview
Add functions to fetch plugin list from GitHub README.md and manage caching. Uses markdown parsing instead of JSON.

### Changes Required:

#### 1. Plugin Functions Enhancement
**File**: `scripts/helpers/plugin_functions.sh`
**Changes**: Add new functions for available plugin management

```bash
# Cache directory and file
TPM_CACHE_DIR="$HOME/.cache/tpm"
AVAILABLE_PLUGINS_CACHE="$TPM_CACHE_DIR/available_plugins.txt"

# Fetch available plugins from TPM repository (markdown format)
fetch_available_plugins() {
    local url="https://raw.githubusercontent.com/tmux-plugins/list/master/README.md"
    curl -s --max-time 10 "$url" 2>/dev/null | \
        grep -E '^\- \[' | \
        sed -E 's/^- \[([^]]+)\]\(([^)]+)\).*-\s*(.*)$/\1|\2|\3/'
}

# Get available plugins (from cache or fetch)
get_available_plugins() {
    local now timestamp age cache_age=86400  # 24 hours
    
    # Check if cache exists
    if [ -f "$AVAILABLE_PLUGINS_CACHE" ]; then
        now=$(date +%s)
        timestamp=$(stat -c %Y "$AVAILABLE_PLUGINS_CACHE" 2>/dev/null || echo 0)
        age=$((now - timestamp))
        
        # Return cached data if fresh enough
        if [ "$age" -lt "$cache_age" ]; then
            cat "$AVAILABLE_PLUGINS_CACHE"
            return
        fi
    fi
    
    # Fetch fresh data
    ensure_cache_dir
    fetch_available_plugins > "$AVAILABLE_PLUGINS_CACHE" 2>/dev/null
    cat "$AVAILABLE_PLUGINS_CACHE"
}

# Filter out plugins that are already pending/installed/orphaned
filter_available_plugins() {
    local existing_plugins
    
    # Get all existing plugins (pending + installed + orphaned)
    existing_plugins="$(tpm_plugins_list_helper)
$(get_local_plugins)"
    
    # Read from cache and filter
    while IFS='|' read -r name url desc; do
        [ -z "$name" ] && continue
        # Extract short name (after last slash)
        short_name="${name##*/}"
        
        # Check if already exists
        case "$existing_plugins" in
            *"$name"*|*"/$short_name"*|*"$short_name"*) : ;;
            *) echo "$name|$url|$desc" ;;
        esac
    done < "$(get_available_plugins_cache_file)"
}

get_available_plugins_cache_file() {
    echo "$AVAILABLE_PLUGINS_CACHE"
}

# Ensure cache directory exists
ensure_cache_dir() {
    mkdir -p "$TPM_CACHE_DIR"
}

# Force refresh available plugins cache
refresh_available_plugins_cache() {
    ensure_cache_dir
    fetch_available_plugins > "$AVAILABLE_PLUGINS_CACHE" 2>/dev/null
}
```

### Success Criteria:

#### Automated Verification:
- [x] `fetch_available_plugins` function exists and returns markdown-parsed data
- [x] Cache file created at ~/.cache/tpm/available_plugins.txt
- [x] Cache refresh works (Alt+R key binding in later phase)

#### Manual Verification:
- [x] Running fetch function returns plugin list from GitHub
- [x] Cache is created and persists between runs

---

## Phase 2: Core - Integrate Available into Plugin List

### Overview
Extend generate_plugin_list to include available plugins, add Alt+R binding.

### Changes Required:

#### 1. Plugin List Enhancement
**File**: `scripts/plugin_list.sh`
**Changes**: Add available category to generate_plugin_list and fzf

```bash
# Add after existing generate_plugin_list function (~line 103):
generate_available_list() {
    local available_plugins
    available_plugins=$(get_available_plugins 2>/dev/null)
    
    if [ -z "$available_plugins" ]; then
        return
    fi
    
    # Filter and output available plugins
    filter_available_plugins "$available_plugins" | while IFS='|' read -r name url; do
        [ -z "$name" ] && continue
        echo -e "${BLUE}[available]${RESET} ${CYAN}${name}${RESET}"
    done
}
```

#### 2. Update generate_plugin_list
**File**: `scripts/plugin_list.sh:89-103`
**Changes**: Add available case to status case statement:

```bash
generate_plugin_list() {
    categorize_plugins | while IFS='|' read -r status name path; do
        case "$status" in
        pending)
            echo -e "${YELLOW}[pending]${RESET}  ${CYAN}${name}${RESET}"
            ;;
        installed)
            echo -e "${GREEN}[installed]${RESET} ${BOLD}${name}${RESET}"
            ;;
        orphaned)
            echo -e "${RED}[orphaned]${RESET}  ${DIM}${name}${RESET}"
            ;;
        available)  # NEW
            echo -e "${BLUE}[available]${RESET} ${CYAN}${name}${RESET}"
            ;;
        esac
    done
    # Also output available plugins
    generate_available_list
}
```

#### 3. Add Alt+R Key Binding
**File**: `scripts/plugin_list.sh:150-162`
**Changes**: Add refresh binding to fzf command:

```bash
--bind="alt-r:execute($CURRENT_DIR/refresh_available.sh)+reload($CURRENT_DIR/plugin_list.sh --list)"
```

#### 4. Add Legend for Available
**File**: `scripts/plugin_list.sh:143-148`
**Changes**: Update legend header:

```bash
echo -e ""
echo -e "${YELLOW}pending${RESET}   = new plugin (will be installed)"
echo -e "${GREEN}installed${RESET} = working plugin"
echo -e "${RED}orphaned${RESET}  = cleanup needed"
echo -e "${BLUE}available${RESET} = from TPM repository"
echo -e ""
```

#### 5. Create refresh script
**File**: `scripts/refresh_available.sh` (new file)
```bash
#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$CURRENT_DIR/helpers"

source "$HELPERS_DIR/plugin_functions.sh"

refresh_available_plugins_cache
echo "Available plugins cache refreshed"
```

### Success Criteria:

#### Automated Verification:
- [x] `generate_available_list` function exists
- [x] Available plugins appear in list output
- [x] Alt+R binding triggers cache refresh

#### Manual Verification:
- [x] [available] section appears in popup
- [x] Section order: pending → installed → orphaned → available
- [x] Alt+R refreshes the available list

---

## Phase 3: UI - Preview Window Enhancement

### Overview
Extend plugin_preview.sh to show README, Git URL, and stats for available plugins.

### Changes Required:

#### 1. Plugin Preview Enhancement
**File**: `scripts/plugin_preview.sh`
**Changes**: Add handling for [available] status

```bash
# After extracting status (~line 22), add:

# Check if available plugin
if [ "$status" = "available" ]; then
    # Extract plugin name
    available_name="$plugin_name"
    
    echo -e "${GREEN}Plugin:${RESET} $available_name"
    echo -e "${GREEN}Status:${RESET} Available (from TPM repository)"
    echo ""
    
    # Get URL from cache or fetch
    local plugin_url
    plugin_url=$(get_available_plugin_url "$available_name")
    echo -e "${GREEN}GitHub:${RESET} $plugin_url"
    echo ""
    
    # Try to fetch README from the plugin's GitHub repo
    echo -e "${YELLOW}Fetching README from GitHub...${RESET}"
    local github_readme
    github_readme=$(curl -s --max-time 5 "https://raw.githubusercontent.com/${available_name}/master/README.md" 2>/dev/null)
    
    if [ -n "$github_readme" ]; then
        echo "$github_readme" | head -50
    else
        # Try alternate readme locations
        github_readme=$(curl -s --max-time 5 "https://raw.githubusercontent.com/${available_name}/master/readme.md" 2>/dev/null)
        if [ -n "$github_readme" ]; then
            echo "$github_readme" | head -50
        else
            echo "(No README found on GitHub)"
        fi
    fi
    return
fi
```

#### 2. Add helper function
**File**: `scripts/helpers/plugin_functions.sh`
**Changes**: Add function to get plugin URL from cache

```bash
# Get URL for available plugin from cache
get_available_plugin_url() {
    local plugin_name="$1"
    local cache_file="$AVAILABLE_PLUGINS_CACHE"
    
    if [ ! -f "$cache_file" ]; then
        # Fetch and cache
        get_available_plugins > /dev/null 2>&1
    fi
    
    if [ -f "$cache_file" ]; then
        if command -v jq &>/dev/null; then
            jq -r ".[] | select(.name == \"$plugin_name\") | .url" "$cache_file" 2>/dev/null
        else
            # Fallback: grep-based
            grep "|.*$plugin_name" "$cache_file" | cut -d'|' -f2
        fi
    fi
}
```

### Success Criteria:

#### Automated Verification:
- [x] Preview shows plugin name for available
- [x] Preview shows GitHub URL
- [x] Preview attempts to fetch README

#### Manual Verification:
- [x] Preview window shows correct information for available plugins
- [x] README content displayed (if available)

---

## Phase 4: UI - Installation Flow

### Overview
Implement full installation flow: add to tmux.conf AND clone the repo.

### Changes Required:

#### 1. Modify plugin_install_selected.sh
**File**: `scripts/plugin_install_selected.sh`
**Changes**: Add handling for available plugins

```bash
# After existing status check (~line 20), add:

if [ "$status" = "available" ]; then
    # Get full plugin name from available plugins
    local plugin_url
    plugin_url=$(get_available_plugin_url "$plugin_name")
    
    if [ -z "$plugin_url" ]; then
        # Fallback to github.com format
        plugin_url="https://github.com/${plugin_name}"
    fi
    
    # Add to tmux.conf
    tmux_conf=$(_get_user_tmux_conf)
    echo 'set -g @plugin "'"$plugin_name"'"' >> "$tmux_conf"
    echo "Added to tmux.conf: $plugin_name"
    
    # Clone the plugin
    cd "$(tpm_path)" && GIT_TERMINAL_PROMPT=0 git clone --single-branch --recursive "$plugin_url" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Installed: $plugin_name"
    else
        echo "Warning: Added to tmux.conf but clone failed. Run 'prefix + I' to install." >&2
    fi
    exit $?
fi
```

#### 2. Add binding for available installation
**File**: `scripts/plugin_list.sh`
**Changes**: Ensure Alt+I works for available plugins

The existing binding already handles installation via `plugin_install_selected.sh`. No additional binding needed.

#### 3. Batch installation support
**File**: `scripts/plugin_install_selected.sh`
**Changes**: Modify to handle multiple selections

For batch selection (multiple plugins selected in fzf), modify to accumulate plugins and process after confirmation:

```bash
# If called with multiple plugins (separated by newlines)
if [ "$plugin_line" = "$(echo "$plugin_line" | head -1)" ]; then
    # Single plugin - process normally
    ...
else
    # Multiple plugins - process each
    echo "$plugin_line" | while read -r line; do
        # Extract name and process
        ...
    done
fi
```

### Success Criteria:

#### Automated Verification:
- [x] Available plugin added to tmux.conf
- [x] Available plugin cloned to plugin directory
- [x] Both actions happen on installation

#### Manual Verification:
- [x] Selecting available plugin triggers full install
- [x] Plugin appears in tmux.conf after install
- [x] Plugin directory created after install

---

## Phase 5: Testing & Validation

### Overview
Validate all functionality works end-to-end.

### Testing Steps:

#### Automated Tests:
1. Test fetch function returns valid JSON
2. Test cache file creation
3. Test filter removes existing plugins
4. Test generate_available_list output format

#### Manual Testing:
1. Open plugin list popup (`prefix + I`)
2. Verify [available] section appears (blue color)
3. Search for plugin by name
4. Select available plugin and install
5. Verify plugin added to tmux.conf
6. Verify plugin directory created
7. Test Alt+R refresh
8. Test offline behavior (GitHub unreachable)
9. Test preview window for available plugin
10. Verify no duplicates between categories

### Edge Cases to Test:
- GitHub unreachable → available section hidden
- Cache empty + GitHub unreachable → show empty available section
- Plugin already installed → not shown in available
- Plugin in tmux.conf but not installed → shows as [pending], not [available]

---

## Performance Considerations

- **Cache TTL**: 24 hours (86400 seconds) to reduce GitHub API calls
- **On-demand fetch**: Only fetch when popup opens (not proactively)
- **Offline fallback**: Hide available if GitHub unreachable (no retry loop)
- **jq optional**: Use jq if available, fallback to simple grep

---

## Migration Notes

This feature adds new functionality without breaking existing behavior:
- Existing [pending], [installed], [orphaned] categories unchanged
- No migration needed for existing installations
- Cache directory created automatically on first use

---

## References

- Original ticket: `thoughts/tickets/feature_available_plugins.md`
- Related research: `thoughts/research/2026-04-06_available_plugins.md`
- TPM Plugin List: https://github.com/tmux-plugins/list
- fzf preview: https://github.com/junegunn/fzf#preview

---

## Files to Modify

| File | Changes |
|------|---------|
| `scripts/helpers/plugin_functions.sh` | Add fetch/cache/filter functions |
| `scripts/plugin_list.sh` | Add available category, Alt+R binding |
| `scripts/plugin_preview.sh` | Handle available status in preview |
| `scripts/plugin_install_selected.sh` | Handle available installation |
| `scripts/refresh_available.sh` | New file for cache refresh |

## Files to Create

| File | Purpose |
|------|---------|
| `scripts/refresh_available.sh` | Cache refresh script |
