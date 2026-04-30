---
date: 2026-04-21T06:09:57Z
git_commit: 433084e64697140e3890fc28eec744021414a6d1
branch: master
repository: tpm-fzf
topic: "Complete tpm_fzf Rewrite - Feature Research"
tags: [tpm, plugin-manager, fzf, tmux, rewrite, research]
last_updated: 2026-04-21
last_updated_by: researcher
last_updated_note: Implementation completed
---

## Ticket Synopsis

This research covers **FEATURE-001: Complete tpm_fzf Rewrite** - a major feature to rewrite the tpm_fzf plugin from scratch with:
- Independent plugin sourcing (no dependency on TPM)
- Improved UI/UX with dynamic actions (like apf)
- Comprehensive error handling with messaging system
- Support for both git clone and gh repo clone
- Plugin validation before showing as available
- Full reimplementation of install/clean/update/update_all

## Summary

The research confirms that tpm_fzf-v2 needs to implement a complete plugin management system inspired by both TPM (tmux plugin manager) and apf (Another Flatpak Manager). The key architectural decisions have been made in the feature ticket, and the implementation will require creating 11+ shell scripts with specific patterns from the research sources.

**Key Findings:**
1. TPM provides core plugin lifecycle scripts at `/home/.config/tmux/plugins/tpm/scripts/`
2. APF provides advanced fzf patterns at `/home/opt/fzf/apf/apf` - specifically dynamic actions (line 103-177), ctrl-h help toggle (line 209-215), and preview window management
3. Current tpm-fzf-v2 directory is empty (only feature ticket exists)
4. The plugins.conf file exists but is empty - needs population from tmux-plugins/list

---

## Detailed Findings

### 1. TPM Scripts Implementation (Primary Reference)

**Location:** `/home/.config/tmux/plugins/tpm/`

#### Core Bin Scripts (entry points)
- `bin/install_plugins:14` - calls `scripts/install_plugins.sh`
- `bin/clean_plugins:14` - calls `scripts/clean_plugins.sh`
- `bin/update_plugins:21` - accepts plugin name or "all", calls `scripts/update_plugin.sh`

#### Core Script Implementations
- `scripts/install_plugins.sh:15-51` - clone plugin, check if already installed, use both direct git URL and GitHub expansion
- `scripts/clean_plugins.sh:15-34` - iterate plugin directories, check if in tpm_plugins_list, remove orphaned
- `scripts/source_plugins.sh:29-37` - source all *.tmux files from plugins in order
- `scripts/update_plugin.sh` - git pull for updates (need to read)

#### Helper Functions
- `scripts/helpers/plugin_functions.sh:71-78` - `tpm_plugins_list_helper()` parses both `@tpm_plugins` (deprecated) and `set -g @plugin` lines
- `scripts/helpers/plugin_functions.sh:83-90` - `plugin_name_helper()` extracts basename, removes .git extension
- `scripts/helpers/plugin_functions.sh:92-96` - `plugin_path_helper()` returns full path to plugin
- `scripts/helpers/plugin_functions.sh:98-104` - `plugin_already_installed()` checks if directory exists and is git repo

**Key TPM Variables:**
- TPM path via `TMUX_PLUGIN_MANAGER_PATH` environment or `tpm_plugins` option
- User config via `_get_user_tmux_conf()` - checks XDG location first, then default `$HOME/.tmux.conf`

---

### 2. APF FZF Patterns (UI Reference)

**Location:** `/home/opt/fzf/apf/apf`

#### Dynamic Actions Pattern (Lines 103-177)
APF dynamically changes fzf actions based on package state:
- Shows "remove" for installed packages (line 193)
- Shows "install" for available packages (line 199)
- Implementation uses `transform-footer` with bash -c (line 177-208)

```bash
# Dynamic action via transform-footer (line 177-208)
--bind 'load,focus,multi:change-footer-label(...)+transform-footer(bash -c '
    if grep -q "^$package" "$installed_packages"; then
        printf "remove"  # red for installed
    else
        printf "install"  # default for available
    fi
')'
```

#### Ctrl-H Help Toggle (Lines 209-215)
APF uses ctrl-h to toggle help display:
```bash
--bind 'ctrl-h:change-footer-label(Change focus to hide)+transform-footer(bash -c '
    printf "<Enter> Execute transaction   <Ctrl-S> Reinstall\n<Alt-I> Show installed ..."
')'
```

#### Preview Window (Lines 103-148)
APF loads preview with package information:
- Uses `preview` with embedded bash
- Shows local info for installed (`yay -Qi`), remote for available (`yay -Si`)
- Shows "(Updatable: X.X.X)" in preview when update available (line 127)

---

### 3. Plugin Categories Implementation

From ticket (lines 40-43):
- `[pending]` - In tmux.conf but not installed (yellow) - NOT IMPLEMENTED IN TPM
- `[installed]` - In tmux.conf and in plugin directory (green)
- `[orphaned]` - In plugin dir but not tmux.conf (red/dim) - TPM clean_plugins logic
- `[available]` - From config file, validated, not in above lists (blue/cyan) - NEW

**TPM Missing:** No concept of "pending" or "available" - only handles installed plugins.

---

### 4. Current tpm-fzf-v2 State

**Location:** `/home/projects/tpm/tpm-fzf/tpm-fzf-v2/`

Existing files:
- `feature_tpm_fzf_rewrite.md` - The feature ticket (263 lines)
- `plugins.conf` - Empty config file waiting for population

**Required structure from ticket (lines 213-235):**
```
tpm-fzf-v2/
├── plugins.conf              # Available plugins config (90+ plugins)
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

---

### 5. Key Technical Details

#### TPM Plugin Parsing (plugin_functions.sh:71-78)
```bash
tpm_plugins_list_helper() {
    echo "$(tmux start-server\; show-option -gqv "$tpm_plugins_variable_name")"
    _tmux_conf_contents "full" |
        awk '/^[ \t]*set(-option)? +-g +@plugin/ { gsub(/'\''/,""); gsub(/'\"'/,""); print $4 }'
}
```

#### TPM Clone Logic (install_plugins.sh:15-35)
```bash
clone() {
    local plugin="$1" local branch="$2"
    cd "$(tpm_path)" &&
        GIT_TERMINAL_PROMPT=0 git clone -b "$branch" --single-branch --recursive "$plugin"
}

clone_plugin() {
    local plugin="$1" local branch="$2"
    clone "$plugin" "$branch" || clone "https://git::@github.com/$plugin" "$branch"
}
```

#### TPM Clean Logic (clean_plugins.sh:15-34)
```bash
clean_plugins() {
    local plugins plugin plugin_directory
    plugins="$(tpm_plugins_list_helper)"
    for plugin_directory in "$(tpm_path)"/*; do
        plugin="$(plugin_name_helper "${plugin_directory}")"
        case "${plugins}" in
            *"${plugin}"*) : ;;  # still referenced
            *) rm -rf "${plugin_directory}" ;;  # orphaned
        esac
    done
}
```

#### APF Help Toggle (apf:209-215)
```bash
--bind 'ctrl-h:change-footer_label(Show help)+transform-footer(bash -c '
    printf "<Enter> Execute transaction   <Ctrl-S> Reinstall\n<Alt-I> Show installed..."
')'
```

---

## Code References

### TPM Source Files
- `/home/.config/tmux/plugins/tpm/bin/install_plugins` - Entry point (14 lines)
- `/home/.config/tmux/plugins/tpm/bin/clean_plugins` - Entry point (14 lines)
- `/home/.config/tmux/plugins/tpm/bin/update_plugins` - With "all" support (24 lines)
- `/home/.config/tmux/plugins/tpm/scripts/install_plugins.sh` - Main install logic (75 lines)
- `/home/.config/tmux/plugins/tpm/scripts/clean_plugins.sh` - Main clean logic (41 lines)
- `/home/.config/tmux/plugins/tpm/scripts/source_plugins.sh` - Plugin sourcing (42 lines)
- `/home/.config/tmux/plugins/tpm/scripts/helpers/plugin_functions.sh` - Core functions (104 lines)

### APF Source Files
- `/home/opt/fzf/apf/apf` - Main implementation (308 lines)
  - Dynamic footer actions: lines 177-208
  - Ctrl-h help toggle: lines 209-215
  - Preview window: lines 103-148

### Notes Reference
- `/home/projects/tpm/tpm-fzf/NOTES.md` - Development notes (85 lines)

---

## Architecture Insights

### Design Decisions (from ticket)

1. **Config File:** `tpm_fzf_v2/plugins.conf` in plugin directory, user configurable via tmux option
2. **Plugin Validation:** Check both `.tmux` file AND README exists for valid tmux plugin
3. **Offline Handling:** Show local only - skip available list when offline
4. **Clone Support:** Both `git clone` and `gh repo clone`
5. **Messaging:** Use `tmux display-message` and tmux options for user input
6. **Default Paths:**
   - Plugin dir: `~/.tmux/plugins/`
   - Key: `prefix + i`
   - Popup: `80% x 80%`

### Key Differences from TPM

| Feature | TPM | tpm_fzf_v2 |
|--------|-----|------------|
| Plugin sources | `@plugin` only | Config file + tmux.conf |
| Dependency | Self-contained | Independent - no TPM dependency |
| Available list | N/A | Yes - from plugins.conf |
| Pending detection | N/A | Yes - in tmux.conf but not installed |
| Orphaned detection | clean_plugins | Yes - in plugin dir not tmux.conf |
| Preview | N/A | Yes - README preview |
| Help toggle | N/A | Yes - ctrl-h |

### Key Differences from Current tpm-fzf

| Feature | Current tpm_fzf | tpm_fzf_v2 |
|---------|----------------|--------------|
| Dependency | On tpm | Independent |
| UI | Basic | Dynamic actions like apf |
| Available list | N/A | Yes - from config |
| Validation | N/A | Yes - .tmux + README |
| Messaging | Basic | Via tmux display-message |
| Preview | Basic | With update check |

---

## Historical Context (from NOTES.md)

**Location:** `/home/projects/tpm/tpm-fzf/NOTES.md`

Key points from development notes:
1. **Config file approach** (line 3-7): Parse URLs from tmux-plugins/list, user can add/remove
2. **Script requirements** (line 11-14): preserve fzf commands, add install/remove/update
3. **Utility scripts** (line 18-30): find_tpm_path, parse_tmux_conf, messaging, requirements, online check
4. **TPM calling** (line 34-38): Call tpm scripts directly for install_all/clean_all/update_all
5. **FZF patterns** (line 42-62): Dynamic actions, ctrl-h help, ansi colors, preview
6. **Sources** (line 82-84): Listed tpm and apf directories

---

## Related Research

No existing research documents in `thoughts/shared/research/` - this is the first research document for tpm-fzf.

---

## Open Questions

1. **Plugin loading order:** How to ensure TPM is sourced last when there are multiple `@plugin` blocks including commented ones?
2. **Config file population:** Need to fetch from tmux-plugins/list and populate plugins.conf before implementation
3. **gh repo clone support:** Need to handle both git and gh with preference detection
4. **Update preview:** How to efficiently check for updates without blocking UI?
5. **Preview performance:** For 90+ available plugins, git fetch for each will be slow - need optimization strategy

---

## Implementation Recommendations

### Phase 1: Core Scripts
1. Create `lib/plugin_functions.sh` - adapt from TPM helper
2. Create `variables.sh` - tmux option handling
3. Create `parse_tmux_conf.sh` - parse all @plugin lines
4. Create `find_tpm_path.sh` - locate or install TPM

### Phase 2: Plugin Lifecycle
1. Create `plugin_install.sh` - single and "all" support
2. Create `plugin_remove.sh` - single only
3. Create `plugin_update.sh` - single and "all" support
4. Create `plugin_clean.sh` - remove orphaned

### Phase 3: FZF Integration
1. Create `plugin_list.sh` - main list with categories
2. Create `plugin_preview.sh` - README preview with update check
3. Create `messaging.sh` - tmux display-message wrapper

### Phase 4: Utilities
1. Create `check_online.sh` - non-blocking GitHub check
2. Create `check_requirements.sh` - dependency validation
3. Create `validate_plugin.sh` - URL validation
4. Create `plugin_source.sh` - reimplement sourcing

### Phase 5: Configuration
1. Populate `plugins.conf` from tmux-plugins/list
2. Create `tpm_fzf.tmux` - keybindings and popup

---

## Next Steps

1. **Immediate:** Update ticket status to "researched"
2. **Pre-implementation:** Populate plugins.conf from https://raw.githubusercontent.com/tmux-plugins/list/master/README.md
3. **First script:** Start with `lib/plugin_functions.sh` adapting TPM's helper
4. **Research follow-up:** May need deeper dive on specific scripts when implementation begins