---
date: 2026-04-21T09:00:00Z
git_commit: 433084e64697140e3890fc28eec744021414a6d1
branch: master
repository: tpm-fzf
topic: "tpm_fzf_v2 Implementation Plan"
tags: [tpm, plugin-manager, fzf, tmux, implementation, plan]
last_updated: 2026-04-21
---

# tpm_fzf_v2 Implementation Plan

## Overview

Implement a complete, self-contained tmux plugin manager with fzf integration. The plugin replaces TPM dependency with independent plugin lifecycle management, featuring a modern UI with dynamic actions and ctrl-h help toggle.

**Target**: Fully functional tpm-fzf-v2 plugin with:
- Plugin list with 4 categories (pending, installed, orphaned, available)
- Install/remove/update/clean operations via fzf
- Preview window with README and update checking
- Independent from TPM (self-sourcing)

## Current State Analysis

**What exists:**
- Feature ticket: `tpm-fzf-v2/feature_tpm_fzf_rewrite.md` (status: researched)
- Research document: `thoughts/research/2026-04-21_tpm_fzf_rewrite.md`
- plugins.conf: Pre-populated with 113 plugins across 6 categories
- Reference implementations:
  - TPM: `/home/.config/tmux/plugins/tpm/scripts/` (install, clean, update, source)
  - APF: `/home/opt/fzf/apf/apf` (dynamic actions, ctrl-h, preview)

**What needs to be created:**
- 12 shell scripts
- 1 tmux keybindings file
- Directory structure

**Key constraint from user**: This is a self-contained reimplementation - do NOT call TPM scripts, implement all functionality directly.

**TPM replacement**: Our plugin_source.sh replaces original TPM entirely. We do NOT call tpm scripts - we implement our own sourcing.

## Desired End State

After completion, users can:
1. Press `prefix + i` to open the plugin manager popup
2. Browse all 4 plugin categories with fzf
3. Preview README for any plugin
4. Install plugins from available list
5. Remove installed plugins
6. Update individual plugins or all
7. Clean orphaned plugins
8. Press ctrl-h to toggle help

### Key Discoveries:
- TPM install logic at `scripts/install_plugins.sh:15-51` - git clone with fallback
- TPM clean logic at `scripts/clean_plugins.sh:15-34` - iterate and remove orphaned
- APF dynamic footer at `apf:177-208` - shows install/remove based on state
- APF ctrl-h at `apf:209-215` - toggle help via transform-footer
- Plugin parsing in `plugin_functions.sh:71-78` - awk for @plugin lines

## What We're NOT Doing

- **TPM integration**: Not calling tpm/bin/* scripts - self-contained
- **find_tpm_path.sh**: No need - plugin is independent
- **Multiple tmux.conf support**: Single config path for v1 (can extend later)
- **Branch selection**: Install at default branch only (can add if needed)
- **Plugin version pinning**: Just latest main (can add if needed)

## Implementation Approach

### Architecture

```
tpm-fzf-v2/
├── plugins.conf              # 113 plugins (exists)
├── tpm_fzf.tmux            # keybindings + popup
├── scripts/
│   ├── plugin_list.sh       # main fzf entry point
│   ├── plugin_preview.sh   # README preview
│   ├── plugin_install.sh   # clone + add to conf
│   ├── plugin_remove.sh    # rm dir + comment conf
│   ├── plugin_update.sh    # git pull
│   ├── plugin_clean.sh     # rm orphaned
│   ├── plugin_source.sh    # source all *.tmux (called by tmux)
│   ├── parse_tmux_conf.sh  # parse @plugin lines
│   ├── check_online.sh     # github connectivity
│   ├── check_requirements.sh # fzf/git/curl check
│   └── validate_plugin.sh  # .tmux + README check
└── lib/
    ├── plugin_functions.sh # shared logic
    ├── utility.sh          # helpers
    └── variables.sh        # tmux options
```

### Strategy
- **Phase order**: Foundation → Lifecycle → UI → Utilities → Configuration
- **Reference patterns**: Adapt TPM for logic, APF for fzf UI
- **Validation**: Each phase produces working artifacts

---

## Phase 1: Foundation

### Overview
Create the shared library and configuration handling - the base other scripts depend on.

### Changes Required

#### 1. lib/plugin_functions.sh
**New file**: Core plugin utilities adapted from TPM

```bash
# Key functions to implement:
- get_plugin_dir()           # from @tpm_fzf_plugin_dir or default
- get_tmux_conf_path()       # from @tpm_fzf_tmux_conf or default
- get_plugins_config()       # from @tpm_fzf_plugins_config
- parse_plugins_from_conf()  # awk for set -g @plugin lines
- get_installed_plugins()    # list directories in plugin_dir
- plugin_name_from_url()     # extract author/repo from URL
- is_plugin_installed()      # check if dir exists and is git
```

**Reference**: TPM `plugin_functions.sh:71-104`

#### 2. lib/utility.sh
**New file**: General helpers

```bash
# Key functions:
- escape_for_fzf()           # sanitize input for fzf
- ensure_dir_exists()        # create dir if missing
- run_git_clone()            # git or gh clone
- file_contains()            # grep pattern in file
```

#### 3. scripts/variables.sh
**New file**: Tmux option getters/setters

```bash
# Tmux options:
- @tpm_fzf_tmux_conf        # tmux.conf path (default: XDG or ~/.tmux.conf)
- @tpm_fzf_plugin_dir      # plugin directory (default: ~/.tmux/plugins/)
- @tpm_fzf_git_command     # git clone or gh repo clone
- @tpm_fzf_plugins_config  # plugins.conf path
- @tpm_fzf_key             # keybinding (default: i)
- @tpm_fzf_popup_w         # popup width % (default: 80)
- @tpm_fzf_popup_h         # popup height % (default: 80)
```

**Reference**: TPM `variables.sh`

### Success Criteria

#### Automated Verification:
- [ ] lib/plugin_functions.sh defines all 7+ functions
- [ ] lib/utility.sh has helper functions
- [ ] scripts/variables.sh reads/writes tmux options

#### Manual Verification:
- [ ] Source lib/plugin_functions.sh in bash, functions work
- [ ] variables.sh correctly reads existing tmux options

---

## Phase 2: Plugin Lifecycle

### Overview
Implement core plugin operations: install, remove, update, clean, source.

### Changes Required

#### 1. scripts/parse_tmux_conf.sh
**New file**: Parse tmux.conf for plugins

```bash
# Parse all set -g @plugin lines (including commented)
# Group between #TPM plugins and #End of Plugins markers

# tmux.conf structure:
# #TPM plugins
# set -g @plugin "tmux-plugins/tpm"
# set -g @plugin "other/plugin"
# #End of Plugins
# run-shell "/full/path/to/tpm-fzf-v2/scripts/plugin_source.sh"
#                                      ^ absolute path

# KEY FUNCTIONS:
# - get_plugins_from_conf()         # awk for set -g @plugin lines
# - ensure_plugin_markers()       # Add markers if missing
# - add_plugin_to_group()          # Insert @plugin between markers
# - remove_plugin_from_group()    # Comment out in group
# - group_plugins()              # Ensure all @plugin are between markers

# Note: Source line uses absolute path to plugin_dir for reliability
```

**Grouping strategy**:
1. Look for `#TPM plugins` / `#End of Plugins` markers
2. If markers exist: insert between them
3. If no markers: add markers around first @plugin, then insert between
4. All `set -g @plugin` lines stay grouped

**Reference**: TPM `plugin_functions.sh:71-78`

#### 2. scripts/plugin_install.sh
**New file**: Install plugin(s)

```bash
# Usage: plugin_install.sh <plugin>|"all"
# - If "all": install all pending plugins
# - If single: install that plugin
# - Add "set -g @plugin 'author/repo'" between #TPM plugins and #End of Plugins
# - Clone repo into plugin_dir
# - Validate plugin before showing (check .tmux + README)
```

**tmux.conf insertion**:
```bash
#TPM plugins
set -g @plugin "tmux-plugins/tpm"
set -g @plugin "user/new-plugin"
#End of Plugins
run-shell "/home/user/.tmux/plugins/tpm-fzf-v2/scripts/plugin_source.sh"
#                ^ absolute path, not tmux var
```

**Reference**: TPM `install_plugins.sh:15-51`

#### 3. scripts/plugin_remove.sh
**New file**: Remove single plugin

```bash
# Usage: plugin_remove.sh <plugin>
# - Comment OUT the @plugin line (prefix with #): # set -g @plugin "..."
# - DO NOT delete the line (preserve for re-enabling)
# - Delete plugin directory
```

**Reference**: TPM clean logic adapted

#### 4. scripts/plugin_update.sh
**New file**: Update plugin(s)

```bash
# Usage: plugin_update.sh <plugin>|"all"
# - Git pull for each plugin
# - Show version if available
```

**Reference**: TPM update logic

#### 5. scripts/plugin_clean.sh
**New file**: Clean orphaned plugins

```bash
# Usage: plugin_clean.sh
# - Find plugins in dir but not in tmux.conf
# - Remove each orphaned plugin directory
```

**Reference**: TPM `clean_plugins.sh:15-34`

#### 6. scripts/plugin_source.sh
**New file**: Source all plugins

```bash
# Usage: plugin_source.sh
# - Source all *.tmux files from installed plugins
# - Run in correct order
```

**Reference**: TPM `source_plugins.sh:29-37`

### Success Criteria

#### Automated Verification:
- [ ] parse_tmux_conf.sh returns plugin list
- [ ] plugin_install.sh clones and adds to conf
- [ ] plugin_remove.sh comments out and removes dir
- [ ] plugin_update.sh runs git pull
- [ ] plugin_clean.sh removes orphaned
- [ ] plugin_source.sh sources all *.tmux files

#### Manual Verification:
- [ ] Install a plugin from available list
- [ ] Remove an installed plugin
- [ ] Update an installed plugin
- [ ] Clean orphaned plugins

---

## Phase 3: FZF Integration & UI

### Overview
Create the main fzf interface with dynamic actions, preview, and help toggle.

### Changes Required

#### 1. scripts/plugin_list.sh
**New file**: Main fzf entry point

```bash
# Build categorized list:
# - [pending] yellow: in tmux.conf, not installed
# - [installed] green: in tmux.conf and installed
# - [orphaned] red: in dir, not in tmux.conf  
# - [available] cyan: from config, validated, not in above

# FZF options:
# - --multi for multiple selection
# - --reverse for top-down
# - --ansi for colors
# - --preview with plugin_preview.sh
# - Dynamic footer for actions
# - ctrl-h toggle help
```

**Reference**: APF `apf:103-177` for dynamic footer

#### 2. scripts/plugin_preview.sh
**New file**: Preview window content

```bash
# For installed:
# - Show local README.md
# - Check if updatable (git fetch && compare)

# For available:
# - Try to fetch remote README
# - Show error if fails

# Show "Updatable: X.X.X" if new version
```

**Reference**: APF `apf:103-148` for preview

#### 3. scripts/messaging.sh
**New file**: User communication

```bash
# Functions:
- msg()         # tmux display-message -p
- msg_error()   # red error message
- msg_success() # green success message
- ask()         # get user input via tmux
```

**Reference**: TPM echo functions

### FZF Keybindings

| Key | Action |
|-----|--------|
| Enter | Select |
| Tab | Multi-select |
| Alt+R | Refresh (+reload) |
| Alt+S | Source plugins |
| Alt+I | Install selected |
| Alt+U | Update selected |
| Alt+D | Remove selected |
| Alt+C | Clean orphaned |
| Ctrl-H | Toggle help |

### Success Criteria

#### Automated Verification:
- [ ] plugin_list.sh shows all 4 categories with colors
- [ ] plugin_preview.sh shows README content
- [ ] messaging.sh displays via tmux

#### Manual Verification:
- [ ] Popup opens with prefix + i
- [ ] Categories display with correct colors
- [ ] Preview shows README
- [ ] Ctrl-h toggles help

---

## Phase 4: Utilities

### Overview
Create supporting scripts for validation, requirements, and connectivity.

### Changes Required

#### 1. scripts/check_requirements.sh
**New file**: Validate dependencies

```bash
# Check:
- fzf is installed and in PATH
- git is installed and executable
- curl is available
- bat or cat for preview

# Exit with error if missing
```

#### 2. scripts/check_online.sh
**New file**: GitHub connectivity

```bash
# Non-blocking check:
# - Try curl to github.com
# - Return 0 if online, 1 if offline
# - Cache result briefly

# Used to show online status in footer
```

#### 3. scripts/validate_plugin.sh
**New file**: Validate plugin is real tmux plugin

```bash
# For available plugins:
# - Parse URL to author/repo
# - Try to access .tmux file in repo
# - Try to access README
# - Return valid/invalid status

# Used before showing as available
```

### Success Criteria

#### Automated Verification:
- [ ] check_requirements.sh exits 0 when all deps present
- [ ] check_online.sh returns correct status
- [ ] validate_plugin.sh validates URLs

#### Manual Verification:
- [ ] Offline mode shows only local plugins
- [ ] Available list filters invalid plugins

---

## Phase 5: Configuration

### Overview
Create tmux keybindings and final integration.

### Changes Required

#### 1. tpm_fzf.tmux
**New file**: Main tmux plugin file (like TPM's tpm)

Our .tmux file does EVERYTHING TPM's does:

```bash
#!/usr/bin/env bash

# 1. Check support tmux version (2.17+)
# 2. Set default path (@tpm_fzf_plugin_dir)
# 3. Set keybindings (prefix+I = install, prefix+U = update, prefix+alt+U = clean)
# 4. Source all *.tmux files (our plugin_source.sh)

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$CURRENT_DIR/scripts"

source "$SCRIPTS_DIR/variables.sh"

get_tmux_option() {
  local option="$1"
  local default_value="$2"
  local option_value="$(tmux show-option -gqv "$option")"
  [ -z "$option_value" ] && echo "$default_value" || echo "$option_value"
}

# Set default plugin directory
set_plugin_dir() {
  local plugin_dir="$(tmux show-option -gqv "@tpm_fzf_plugin_dir")"
  [ -z "$plugin_dir" ] && tmux set -g @tpm_fzf_plugin_dir "~/.tmux/plugins/"
}

# Source all *.tmux files from plugins
source_plugins() {
  "$SCRIPTS_DIR/plugin_source.sh" >/dev/null 2>&1
}

# Keybindings - match TPM pattern
set_key_bindings() {
  local key="$(get_tmux_option "@tpm_fzf_key" "i")"
  # Our popup: prefix + I
  tmux bind-key "$key" display-popup -w 80% -h 80% -B -E "bash '$SCRIPTS_DIR/plugin_list.sh'"
  # For compatibility: also bind I + shift for TPM-style
}

# Check version, set paths, bind keys, source plugins
main() {
  # check tmux version >= 2.17
  set_plugin_dir
  set_key_bindings
  source_plugins
}
main
```

**Key similarity to TPM**:
- Uses CURRENT_DIR to find scripts (like TPM)
- get_tmux_option() with defaults (like TPM)
- set keybindings on source (like TPM)
- calls our plugin_source.sh (like TPM calls theirs)

**Our extra**:
- Full fzf popup with categories
- dynamic actions
- ctrl-h help toggle

#### 2. Plugin sourcing integration

User adds to tmux.conf:

```bash
#TPM plugins
set -g @plugin "user/tpm-fzf-v2"
#End of Plugins
run-shell "/home/user/.tmux/plugins/tpm-fzf-v2/tpm_fzf.tmux"
```

Our .tmux handles everything - keybindings, sourcing, version check.

### Success Criteria

#### Automated Verification:
- [ ] tpm_fzf.tmux contains all keybindings
- [ ] scripts are executable (chmod +x)

#### Manual Verification:
- [ ] prefix + i opens popup
- [ ] Help shows correct bindings

---

## Testing Strategy

### Phase Testing

**Phase 1 (Foundation):**
- Source lib/plugin_functions.sh in terminal
- Test: `plugin_name_from_url "https://github.com/tmux-plugins/tpm"`

**Phase 2 (Lifecycle):**
- Create test plugin directory
- Install a test plugin
- Remove it
- Update it
- Clean orphaned

**Phase 3 (UI):**
- Open popup with prefix + i
- Navigate categories
- Preview a plugin
- Toggle help

**Phase 4 (Utilities):**
- Run with missing dependency
- Test offline mode
- Validate fake vs real plugin

**Phase 5 (Config):**
- Source in tmux.conf
- Test keybinding

### Edge Cases
- Empty plugins.conf
- No tmux.conf
- Permission denied on plugin dir
- Git not installed
- Offline with no plugins installed
- Duplicate plugin in config and tmux.conf

---

## Performance Considerations

1. **Available list**: 113 plugins - don't fetch all at once
   - Only validate when user hovers/previews
   - Cache validation results

2. **Update check**: Don't block UI
   - Use async git fetch in preview
   - Show "checking..." while loading

3. **Preview**: Use bat for syntax highlighting if available

---

## Migration Notes

This is a v2 - users will migrate from current tpm-fzf or fresh install.

For existing tpm users:
- Can use alongside TPM initially
- Or replace TPM entirely with tpm_fzf_v2

---

## References

- Original ticket: `tpm-fzf-v2/feature_tpm_fzf_rewrite.md`
- Research: `thoughts/research/2026-04-21_tpm_fzf_rewrite.md`
- TPM reference: `/home/.config/tmux/plugins/tpm/scripts/`
- APF reference: `/home/opt/fzf/apf/apf`
- plugins.conf: `tpm-fzf-v2/plugins.conf` (113 plugins)

---

## Implementation Order

1. lib/utility.sh
2. lib/plugin_functions.sh
3. scripts/variables.sh
4. scripts/parse_tmux_conf.sh
5. scripts/plugin_install.sh
6. scripts/plugin_remove.sh
7. scripts/plugin_update.sh
8. scripts/plugin_clean.sh
9. scripts/plugin_source.sh
10. scripts/messaging.sh
11. scripts/build_fzf_list.sh
12. scripts/plugin_list.sh
13. scripts/plugin_preview.sh
14. scripts/check_requirements.sh
15. scripts/check_online.sh
16. scripts/validate_plugin.sh
17. tpm_fzf.tmux

**Total: 17 files created**