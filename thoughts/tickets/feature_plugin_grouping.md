---
type: feature
priority: high
created: 2026-04-18T23:30:00Z
status: created
tags: [tpm-fzf, plugin-grouping, tmux-conf, setup]
keywords: [plugin grouping, tmux.conf markers, setup script, duplicates]
patterns: [tmux.conf parsing, plugin markers, duplicate removal]
---

# FEATURE-002: Plugin grouping in tmux.conf

## Description

Add feature to group all plugins in tmux.conf between `#TPM plugins` and `#End of plugin list` markers, with proper ordering: critical options first, plugins in the group, then plugin-specific configuration, with tpm sourced last.

## Context

User wants:
1. All `@plugin` lines grouped between markers
2. Group placed after critical options (set term, etc.) 
3. Group placed before plugin-specific config (set -g @tokyo-night-theme, etc.)
4. tpm sourced last
5. Interactive setup to enable/configure this feature
6. When installing from [available], insert in the group
7. Group both active and inactive (commented out) plugins
8. Automatically remove duplicates from fzf list

## Requirements

### Functional Requirements

- [ ] Create setup script for interactive configuration
- [ ] Parse tmux.conf and identify section locations
- [ ] Add/verify TPM markers (`#TPM plugins` / `#End of plugin list`)
- [ ] Migrate existing @plugin lines into the group
- [ ] Detect duplicates and remove them
- [ ] Maintain proper ordering: options → plugins → plugin config → tpm source
- [ ] When installing from [available], insert in the group

### Setup Script Requirements

- [ ] Interactive wizard mode
- [ ] Command-line argument mode
- [ ] Option to enable/disable grouping
- [ ] Option to customize marker labels
- [ ] Configuration stored in tmux options

### Non-Functional Requirements

- [ ] Non-destructive (backup tmux.conf first)
- [ ] Idempotent (can run multiple times safely)
- [ ] Works with existing tpm configurations

## Current State

- tpm-fzf has plugin management scripts
- No grouping mechanism exists

## Desired State

- Setup script available: `bin/setup` or `scripts/setup.sh`
- tmux.conf has proper markers
- Plugins grouped between markers
- Proper ordering maintained

## Research Context

### Keywords to Search

- tmux-conf-markers - How tpm handles markers
- duplicate-removal - Finding duplicates in lists
- section-ordering - Where to place plugins in tmux.conf

### Patterns to Investigate

- tpm marker patterns - `#{TPM|PLUGINS|...`
- tmux.conf ordering - Config file structure

### Key Decisions Made

- All @plugin lines should be grouped
- Markers: `#TPM plugins` / `#End of plugin list`
- tpm sourced last
- Both interactive and args-based setup

## Success Criteria

### Automated Verification

- [ ] Setup script is executable
- [ ] Script runs without errors
- [ ] Markers are placed correctly

### Manual Verification

- [ ] tmux.conf has proper markers
- [ ] Plugins are between markers
- [ ] tpm is sourced last
- [ ] No duplicates in list

## Notes

- Setup should be interactive wizard
- Should support --help and CLI args
- Need to handle both active and commented plugins