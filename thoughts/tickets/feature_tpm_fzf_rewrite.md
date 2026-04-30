---
type: feature
priority: high
created: 2026-04-21T00:00:00Z
status: created
tags: [tmux, plugin-manager, fzf, tpm, rewrite]
keywords: [tpm, plugin_manager, fzf, tmux_plugins, plugin_installation]
patterns: [fzf_integration, tmux_popup, plugin_lifecycle, messaging_system]
---

# FEATURE-001: Complete tpm_fzf Rewrite

## Description

Rewrite the tpm_fzf plugin from scratch with a complete reimplementation of TPM functionality. This is a major feature that provides fuzzy-finding plugin management for tmux with an improved UI/UX, independent plugin sourcing, and better error handling.

## Context

The current tpm_fzf has partial functionality but relies on tpm for core operations. This rewrite aims to:
- Make tpm_fzf independent from tpm
- Improve UI/UX with dynamic actions (similar to apf)
- Add comprehensive error handling with messaging system
- Support both git clone and gh repo clone
- Validate plugins before showing as available
- Reimplement install/clean/update/update_all functionality

## Requirements

### 1. Plugin Discovery & Configuration

- **Config file location**: Default to `tpm_fzf_v2/plugins.conf` in plugin directory, but configurable via tmux option
- **Config file format**: One URL per line (GitHub URLs only by default)
- **Parsing**: Extract `author/repo` format from URLs
- **Validation**: Check both `.tmux` file AND README exists to verify valid tmux plugin
- **Available list**: Parse config, filter out installed/orphaned/pending plugins, show only `author/repo` format
- **User editing**: Users can add/remove URLs from config file

### 2. Plugin Categories

- `[pending]` - In tmux.conf but not installed (yellow)
- `[installed]` - In tmux.conf and in plugin directory (green)
- `[orphaned]` - In plugin dir but not in tmux.conf (red/dim) - show as repo only
- `[available]` - From config file, validated, not in above lists (blue/cyan)

### 3. Core Scripts Needed

#### plugin_list.sh
- List all plugins in categorized format with colors
- Fzf integration with preview window
- Preserve existing fzf commands patterns
- Add preview script for README viewing

#### plugin_install.sh
- Install specific selected plugin
- Accept plugin as argument OR "all" for batch
- Add to tmux.conf between markers
- Clone repo into plugin directory
- Validate plugin is tmux plugin before install

#### plugin_remove.sh
- Remove/delete specific plugin
- Comment out in tmux.conf (installed)
- Delete plugin directory (orphaned)
- Accept single plugin argument

#### plugin_update.sh
- Reimplement tpm's update functionality
- Accept single plugin OR "all" as argument
- Git pull for updates
- Check version in preview and show if updatable

#### plugin_clean.sh
- Remove orphaned plugins (not in tmux.conf)
- Reimplement similar to tpm's clean_plugins

#### plugin_source.sh
- Reimplement tpm's plugin sourcing
- Source all installed plugins in correct order

### 4. Utility Scripts

#### find_tpm_path.sh
- Find TPM path or ask user
- Check if sourced in tmux.conf
- Offer to install if not found

#### parse_tmux_conf.sh
- Parse tmux.conf for all `set -g @plugin` lines
- Include commented ones
- Ensure TPM is sourced at end
- Group plugin definitions

#### messaging.sh
- Display messages via `tmux display-message`
- Get input from user via tmux
- Handle errors:
  - tmux.conf not found, prompt for path
  - Plugin directory not found, offer to create
  - Plugin install/remove/update notifications
  - User input should update tmux options

#### check_online.sh
- Check if GitHub is reachable
- Non-blocking (load list first, update if online)
- Show online status in help/footer
- If offline, show only local plugins

#### check_requirements.sh
- Validate dependencies: fzf, git, curl, bat/cat
- Check git is executable
- Run on first execution
- Use messaging system for errors

#### validate_plugin.sh
- Parse user-provided URLs
- Check for `.tmux` file in repo
- Verify repo is reachable
- Prompt user if errors (not tmux plugin, unreachable)

### 5. Variables & Configuration

#### tpm_fzf.tmux
- Popup command: `tmux display-popup -w 80% -h 80% -B -E bash scripts/plugin_list.sh`
- Keybinding to run popup
- Configure popup dimensions

#### variables.sh
- Get/set tmux options:
  - `@tpm_fzf_tmux_conf` - tmux.conf path
  - `@tpm_fzf_plugin_dir` - plugin directory (default: ~/.tmux/plugins/)
  - `@tpm_fzf_git_command` - git clone or gh repo clone
  - `@tpm_fzf_plugins_config` - path to plugins config file

### 6. FZF Integration

#### Keybindings (call our scripts)
- `Alt+R` - refresh available list (+reload)
- `Alt+S` - source plugins
- `Alt+I` - install selected plugin
- `Alt+U` - update selected plugin (single)
- `Alt+D` - delete/remove selected
- `Alt+C` - clean orphaned
- `Tab` - multi-select

#### Keybindings (call TPM directly)
- `Alt+Shift+I` - install all plugins (call TPM)
- `Alt+Shift+U` - update all (call TPM with "all")
- `Alt+Shift+C` - clean all (call TPM)

#### UI Features
- Dynamic actions per category:
  - [installed] - show remove + clean options
  - [available] - show install only (if preview loaded successfully)
  - [orphaned] - show clean option
  - [pending] - show install option
- Ctrl-H toggle help (like apf)
- Keep ansi colors for preview
- Legend in help menu (ctrl-h)
- Show online status in footer

### 7. Preview Functionality

- Local README for installed plugins
- Git fetch for available plugins (check in preview for updates)
- Show version info if available
- Show "Updatable: X.X.X" in preview if new version
- Use git fetch method (current implementation)

### 8. TPM Scripts Integration

Call these from tpm directory when needed:
- `tpm/bin/install_plugins` - for install all
- `tpm/bin/clean_plugins` - for clean all
- `tpm/bin/update_plugins all` - for update all
- Or reimplement and integrate messaging

### 9. Plugin Source Order

- Ensure plugins are sourced in correct order
- TPM should be sourced last
- Handle multiple `@plugin` blocks including commented

## Research Context

### Keywords to Search
- tmux_plugin_manager - tpm architecture
- tpm_scripts - install/clean/update implementation
- fzf_advanced_patterns - dynamic actions, ctrl-h help toggle
- plugin_functions - parsing tmux.conf
- tmux_display_popup - popup configuration

### Patterns to Investigate
- apf_dynamic_actions - how apf shows context-aware options
- apf_help_toggle - ctrl-h binding technique
- tpm_plugin_bootstrap - plugin loading order
- git_fetch_readme - fetching remote README

### Key Decisions Made
- Config file in plugin dir by default, user configurable
- Validate both .tmux and README for available plugins
- Show local only when offline (skip available)
- Support both git clone and gh repo clone
- Reimplement install/clean/update (not call tpm)
- Check for updates in preview window
- Use messaging via tmux display-message
- Default plugin dir: ~/.tmux/plugins/
- Default key: prefix + i
- Default popup: 80% x 80%
- Run sanity checks on first execution

## Code Structure

```
tpm-fzf-v2/
├── plugins.conf              # Available plugins config
├── tpm_fzf.tmux            # Main tmux keybindings
├── scripts/
│   ├── plugin_list.sh       # Main fzf list
│   ├── plugin_preview.sh   # README preview
│   ├── plugin_install.sh # Install (single or all)
│   ├── plugin_remove.sh # Remove (single)
│   ├── plugin_update.sh # Update (single or all)
│   ├── plugin_clean.sh # Clean orphans
│   ├── plugin_source.sh # Source plugins
│   ├── variables.sh    # Configuration
│   ├── find_tpm_path.sh   # Find TPM
│   ├── parse_tmux_conf.sh # Parse config
│   ├── messaging.sh     # User messaging
│   ├── check_online.sh  # Network check
│   ├── check_requirements.sh # Sanity checks
│   └── validate_plugin.sh # Plugin validation
└── lib/
    ├── plugin_functions.sh
    └── utility.sh
```

## Success Criteria

### Automated Verification
- [ ] Config file parses correctly
- [ ] Plugin list shows all 4 categories
- [ ] fzf preview works
- [ ] Install plugin adds to tmux.conf and clones
- [ ] Remove plugin comments out and deletes dir
- [ ] Update plugin pulls changes
- [ ] Clean removes orphaned
- [ ] Ctrl-h toggles help

### Manual Verification
- [ ] Popup opens with prefix + i
- [ ] Available validated before showing
- [ ] Offline shows local only
- [ ] Help shows correct bindings
- [ ] Online status displayed
- [ ] Update check in preview works
- [ ] Both git and gh work

## Notes

- Pre-built plugins.conf with 90+ tmux plugins from tmux-plugins/list
- Based on apf for UI patterns (ctrl-h toggle, dynamic actions)
- Based on tpm for plugin lifecycle
- Independent from tpm (own sourcing)