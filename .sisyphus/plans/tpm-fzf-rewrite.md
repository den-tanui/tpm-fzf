# Plan: tpm_fzf Complete Rewrite

## TL;DR

> **Quick Summary**: Complete rewrite of tpm_fzf as an independent tmux plugin manager with fzf integration. Provides fuzzy-finding UI for managing plugins without depending on TPM for core operations.

> **Deliverables**:
> - 11 shell scripts in `scripts/` directory
> - 2 library files in `lib/` directory
> - `tpm_fzf.tmux` keybindings file
> - Pre-populated `plugins.conf` with 90+ tmux plugins

> **Estimated Effort**: Large
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: vars.sh → lib → core scripts → fzf integration → final QA

---

## Context

### Original Request
Rewrite tpm_fzf plugin from scratch with complete reimplementation of TPM functionality. This is a major feature that provides fuzzy-finding plugin management for tmux with improved UI/UX, independent plugin sourcing, and better error handling.

### Interview Summary

**Key Discussions**:
- Config file `plugins.conf` already exists with 90+ plugins
- 4 categories: pending, installed, orphaned, available
- independent from TPM - reimplement install/clean/update/source
- Based on apf for UI patterns (ctrl-h toggle, dynamic actions)
- Non-blocking network check
- Support both git clone and gh repo clone
- User wants non-interactive mode for testing

**Research Findings**:
- Existing implementation has lib/plugin_functions.sh with categorize_plugins, get_local_plugins
- tests/test_plugin_list.sh exists for --list mode
- plugins.conf already populated in tpm-fzf-v2/
- **apf research needed** - Fetch from https://github.com/chriskouchouci/apf for dynamic actions + ctrl-h patterns

### Metis Review

**Identified Gaps (addressed)**:
1. Non-interactive mode - verify --list flag works without tty (exists in current, verify)
2. tmux.conf not found - messaging.sh needs to handle
3. No network - check_online.sh non-blocking must work
4. Duplicate URLs - add deduplication logic
5. Uncommitted changes on update - add warning

---

## Work Objectives

### Core Objective
Build tpm_fzf_v2 as an independent tmux plugin manager with fzf UI that works without TPM dependency.

### Concrete Deliverables
- Working popup with `prefix + i` keybinding
- 4-category plugin list (pending/installed/orphaned/available)
- Install/remove/update/clean plugins independently
- Help menu toggle (ctrl-h)
- Non-interactive --list mode for testing

### Definition of Done
- [ ] `prefix + i` opens popup with categorized plugin list
- [ ] All 4 categories display with correct colors
- [ ] fzf preview shows README for installed plugins
- [ ] --list mode outputs without tty requirement

### Must Have
- Independent from tpm (own plugin sourcing)
- Config file parsing with author/repo extraction
- Plugin validation (.tmux + README)
- Non-blocking online check
- Messaging system for errors

### Must NOT Have (Guardrails)
- Don't modify parent tpm-fzf installation
- Don't require tpm to be installed
- Don't block UI on network check
- Don't install invalid plugins (must validate first)

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed.

### Test Decision
- **Existing test infrastructure**: YES - tests/test_plugin_list.sh
- **Automated tests**: Tests after implementation (faster delivery)
- **Non-interactive mode**: MUST work for testing (--list flag)

### QA Policy
Every task includes agent-executed QA scenarios:
- Test --list mode produces correct output
- Test plugin categorization logic
- Test fzf bindings (when terminal available)

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation - can start immediately):
├── Task 1: variables.sh - tmux options + paths
├── Task 2: utility.sh - common helpers
├── Task 3: lib/plugin_functions.sh - core logic
├── Task 4: check_requirements.sh - sanity checks
└── Task 5: check_online.sh - network check

Wave 2 (Core Scripts - after Wave 1):
├── Task 6: messaging.sh - error handling
├── Task 7: find_tpm_path.sh - TPM discovery
├── Task 8: parse_tmux_conf.sh - config parsing
├── Task 9: validate_plugin.sh - plugin validation
└── Task 10: plugin_source.sh - plugin sourcing

Wave 3 (Plugin Actions - max parallel):
├── Task 11: plugin_list.sh - main fzf UI
├── Task 12: plugin_preview.sh - README preview
├── Task 13: plugin_install.sh - install plugins
├── Task 14: plugin_remove.sh - remove plugins
├── Task 15: plugin_update.sh - update plugins
├── Task 16: plugin_clean.sh - clean orphans

Wave 4 (Integration):
├── Task 17: tpm_fzf.tmux - keybindings + popup
└── Task 18: Final integration QA → PRESENT RESULTS → GET USER OKAY
```

### Dependency Matrix
- **1-5**: - - Wave 2, Wave 3, Wave 4
- **6-10**: 1,3,4 - 11-16, Wave 4
- **11**: 2,3,9 - 18, Wave 4
- **12**: 9 - 18, Wave 4
- **13-16**: 2,10 - 17, 18
- **17**: 11 - 18, Wave 4
- **18**: 11-17 - DONE

---

## TODOs

### Wave 1: Foundation

- [ ] 1. variables.sh - Configuration via tmux options

  **What to do**:
  - Define all tmux option names
  - Get/set functions for each option
  - Default values
  - Plugin directory path resolution

  **Must NOT do**:
  - Hardcode paths (must use tmux options)

  **Recommended Agent Profile**:
  > **Category**: `quick` - Simple shell script, well-defined inputs
    - Reason: Configuration file with clear structure
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 2-5)
  - **Parallel Group**: Wave 1
  - **Blocks**: Tasks 6-18
  - **Blocked By**: None (can start immediately)

  **Acceptance Criteria**:
  - [ ] Get @tpm_fzf_plugin_dir returns default or custom
  - [ ] Get @tpm_fzf_tmux_conf returns path

  **QA Scenarios**:
  ```
  Scenario: variables.sh loads and exports correctly
    Tool: Bash
    Steps:
      1. cd tpm-fzf-v2/scripts && bash -c 'source variables.sh; echo "$tpm_fzf_plugin_dir"'
    Expected Result: Path string is output (not empty)
  ```

- [ ] 2. utility.sh - Common helper functions

  **What to do**:
  - ensure_dir_exists function
  - fail_helper function
  - exit_value_helper function
  - Additional utilities from research

  **References** (from existing lib/utility.sh):
  - `/home/projects/tpm/tpm-fzf/lib/utility.sh` - Current util functions

  **Acceptance Criteria**:
  - [ ] Functions are reusable

- [ ] 3. lib/plugin_functions.sh - Core plugin logic

  **What to do**:
  - Categorize plugins (pending/installed/orphaned)
  - Get local plugins
  - Parse tmux.conf @plugin entries
  - Extract plugin names from URLs

  **References** (from existing code):
  - `/home/projects/tpm/tpm-fzf/lib/plugin_functions.sh` - Adapt categorize_plugins

  **Acceptance Criteria**:
  - [ ] categorize_plugins outputs correct format

- [ ] 4. check_requirements.sh - Sanity checks

  **What to do**:
  - Check fzf is installed
  - Check git is executable
  - Check curl is available
  - Check tmux version (2.6+)
  - Exit with clear error if missing

  **Acceptance Criteria**:
  - [ ] Exits 1 if fzf missing
  - [ ] Exits 1 if git missing

- [ ] 5. check_online.sh - Network status

  **What to do**:
  - Check GitHub connectivity
  - Non-blocking (don't wait)
  - Echo online/offline status
  - Show status in footer

  **Acceptance Criteria**:
  - [ ] Returns "online" or "offline" quickly

### Wave 2: Core Scripts

- [ ] 6. messaging.sh - User communication

  **What to do**:
  - Display messages via tmux display-message
  - Get input via tmux prompt
  - Handle: tmux.conf not found
  - Handle: plugin directory not found
  - Handle: install/remove/update notifications

  **References**:
  - NOTES.md mentions messaging utility

  **Acceptance Criteria**:
  - [ ] Can display error message in tmux
  - [ ] Can prompt for input

- [ ] 7. find_tpm_path.sh - TPM reference (optional)

  **What to do**:
  - Find TPM path IF it exists (for reference/legacy only)
  - Don't require TPM - our code is self-contained
  - Optional: show existing plugins from TPM dir as "orphaned" or "installed"
  - No prompts, no errors if TPM not found

  **Acceptance Criteria**:
  - [ ] Returns TPM path if exists, empty if not (no errors)

- [ ] 8. parse_tmux_conf.sh - Config parsing

  **What to do**:
  - Parse all `set -g @plugin` lines
  - Include commented ones
  - Ensure TPM is sourced last
  - Group plugin definitions

  **References**:
  - NOTES.md: "parse tmux.conf and group all set -g @plugins even commented ones"

  **Acceptance Criteria**:
  - [ ] Extracts all @plugin lines

- [ ] 9. validate_plugin.sh - Plugin validation

  **What to do**:
  - Parse URL to extract author/repo
  - Check .tmux file exists in repo
  - Check README exists
  - Verify repo is reachable
  - Prompt user if invalid

  **References**:
  - feature spec: "Check both .tmux file AND README exists to verify valid tmux plugin"

  **Acceptance Criteria**:
  - [ ] Returns valid if .tmux + README exist
  - [ ] Returns invalid otherwise

- [ ] 10. plugin_source.sh - Plugin sourcing

  **What to do**:
  - Source all installed plugins in order
  - Ensure TPM sourced last
  - Handle sourcing errors gracefully

  **References**:
  - feature spec: "Reimplement tpm's plugin sourcing"

  **Acceptance Criteria**:
  - [ ] Sources plugins in correct order

### Wave 3: Plugin Actions (Max Parallel)

- [ ] 11. plugin_list.sh - Main fzf interface

  **What to do**:
  - List all plugins categorized with colors
  - Fzf integration with preview
  - Keybindings for actions
  - --list mode for non-interactive testing
  - Ctrl-h toggle help
  - Legend display

  **UI Features** (from feature spec):
  - **Dynamic actions per category**:
    - [installed] - show remove + update options
    - [available] - show install only (if preview loaded)
    - [orphaned] - show clean option
    - [pending] - show install option
  - **Ctrl-h toggle help** - hide/show keybindings legend
  - **Keep ANSI colors** - preserve colors in preview window
  - **Legend in help menu** - show keybindings when ctrl-h pressed
  - **Online status in footer** - show network status (from check_online.sh)

  **References** (adapt from existing):
  - `/home/projects/tpm/tpm-fzf/scripts/plugin_list.sh` - Main script
  - **apf** (https://github.com/chriskouchouci/apf) - UI patterns to research:
    - dynamic actions per plugin category
    - ctrl-h toggle help technique
    - ansi color preservation

  **Keybindings to implement**:
  - Alt+R - refresh available
  - Alt+S - source plugins
  - Alt+I - install selected
  - Alt+U - update selected
  - Alt+D - delete
  - Alt+C - clean orphans
  - Tab - multi-select
  - Ctrl-h - toggle help/legend

  **Bulk keybindings** (use our reimplemented scripts, NOT tpm):
  - Ctrl+Shift+I - install all plugins (calls plugin_install.sh --all)
  - Ctrl+Shift+U - update all plugins (calls plugin_update.sh --all)
  - Ctrl+Shift+C - clean orphaned plugins (calls plugin_clean.sh)

  **Acceptance Criteria**:
  - [ ] --list mode works without tty
  - [ ] Shows 4 categories with colors
  - [ ] Ctrl-h toggles help visibility
  - [ ] Online status shown in footer
  - [ ] Actions change based on plugin category

- [ ] 12. plugin_preview.sh - README preview

  **What to do**:
  - Show local README for installed plugins
  - Show remote README for available (git fetch)
  - Show version info if available in _tmux_.tmux file
  - Show "Updatable: X.X.X" in preview if new version available
  - Preserve ANSI colors for preview content

  **References**:
  - `/home/projects/tpm/tpm-fzf/scripts/plugin_preview.sh` - Existing preview

  **Acceptance Criteria**:
  - [ ] Shows README for installed plugin
  - [ ] Handles missing README gracefully

- [ ] 13. plugin_install.sh - Install plugins

  **What to do**:
  - Install single plugin
  - Install all (--all flag)
  - Add to tmux.conf between markers
  - Clone repo to plugin directory
  - Validate before install

  **Acceptance Criteria**:
  - [ ] Installs single plugin
  - [ ] Installs all with --all flag
  - [ ] Adds to tmux.conf

- [ ] 14. plugin_remove.sh - Remove plugins

  **What to do**:
  - Remove single plugin
  - Comment out in tmux.conf (installed)
  - Delete directory (orphaned)

  **Acceptance Criteria**:
  - [ ] Comments out in tmux.conf
  - [ ] Deletes plugin directory

- [ ] 15. plugin_update.sh - Update plugins

  **What to do**:
  - Update single plugin
  - Update all (--all flag)
  - Git pull for updates
  - Check version in preview

  **Acceptance Criteria**:
  - [ ] Updates single plugin
  - [ ] Updates all with --all flag

- [ ] 16. plugin_clean.sh - Clean orphaned

  **What to do**:
  - Remove orphaned plugins
  - Not in tmux.conf but in plugin dir
  - Confirm before delete

  **Acceptance Criteria**:
  - [ ] Removes orphaned plugins

### Wave 4: Integration

- [ ] 17. tpm_fzf.tmux - Keybindings + popup

  **What to do**:
  - Set @tpm_fzf_* tmux options
  - Bind key to open popup
  - Configure popup dimensions
  - popup command: `tmux display-popup -w 80% -h 80% -B -E bash scripts/plugin_list.sh`

  **References** (existing):
  - `/home/projects/tpm/tpm-fzf/tpm_fzf.tmux` - Current binding

  **Acceptance Criteria**:
  - [ ] Binds prefix+i to popup

- [ ] 18. Final Integration QA

  **QA Scenarios**:
  ```
  Scenario: Full plugin list displays
    Tool: Bash
    Preconditions: Plugins directory with plugins
    Steps:
      1. cd tpm-fzf-v2/scripts && bash plugin_list.sh --list
    Expected Result: Categorized list output (no tty needed)
  ```

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE.

- [ ] F1. **Plan Compliance Audit** — Verify all Must Have items implemented
- [ ] F2. **Code Quality Review** — Lint, verify no obvious errors
- [ ] F3. **Real Manual QA** — Execute QA scenarios from tasks
- [ ] F4. **Scope Fidelity Check** — No creep beyond spec

---

## Commit Strategy

- Wave 1: `feat(foundation): add configuration and lib scripts`
- Wave 2: `feat(core): add messaging, parsing, validation scripts`
- Wave 3: `feat(actions): add plugin management scripts`
- Wave 4: `feat(integration): add tmux keybindings and final QA`

---

## Success Criteria

### Verification Commands
```bash
# Test --list mode (non-interactive)
cd tpm-fzf-v2/scripts && bash plugin_list.sh --list
# Expected: Categorized plugin list output

# Test categorization
source ../lib/plugin_functions.sh
categorize_plugins
# Expected: status|name|path format
```

### Final Checklist
- [ ] All Must Have items present
- [ ] All Must NOT Have items absent
- [ ] --list mode works without tty
- [ ] 4 categories display correctly