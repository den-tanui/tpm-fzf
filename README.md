# tpm-fzf

An fzf-powered interactive plugin manager for [tpm](https://github.com/tmux-plugins/tpm) (Tmux Plugin Manager).

## Overview

tpm-fzf provides a modern, interactive interface for managing your tmux plugins using [fzf](https://github.com/junegunn/fzf) and tmux popups. Browse, install, update, and delete your plugins through a beautiful fzf-driven menu with live previews.

## Features

- **Interactive Plugin List**: Browse all plugins categorized by status (pending, installed, orphaned)
- **Available Plugins**: Browse and install from the official TPM plugin repository
- **Live Preview**: Preview plugin details before taking action
- **Popup Interface**: Runs in a tmux popup for a clean, focused experience
- **Plugin Actions**:
  - Install new plugins
  - Update existing plugins
  - Delete plugins
  - Source/reload plugins

## Requirements

- [tmux](https://github.com/tmux/tmux) (v2.6+ recommended for popup support)
- [fzf](https://github.com/junegunn/fzf) (v0.30.0+ recommended)
- [tpm](https://github.com/tmux-plugins/tpm) (must be installed - **required dependency**)

## Installation

1. Add tpm-fzf to your tmux.conf plugins:

```bash
set -g @plugin 'your-username/tpm-fzf'
```

2. Reload tmux configuration:

```bash
tmux source-file ~/.tmux.conf
```

The default keybinding is lowercase `i` (press `prefix + i` to open).

## Usage

### Default Keybinding

- `prefix + i` - Open tpm-fzf plugin manager

### Keyboard Shortcuts

Within the fzf interface:

| Key | Action |
|-----|--------|
| `Enter` | Confirm selection |
| `Tab` | Multi-select |
| `Alt+R` | Refresh available plugins |
| `Alt+S` | Source all plugins |
| `Alt+I` | Install selected |
| `Alt+U` | Update selected |
| `Alt+D` | Delete selected |
| `Alt+C` | Clean orphaned plugins |

## Configuration

### Keybinding

Change the default keybinding (default: `i`):

```bash
set -g @tpm-fzf-key "f"  # Use prefix + f instead
```

### Popup Options

Customize the popup dimensions:

```bash
# Enable/disable popup mode (default: on)
set -g @tpm-fzf-popup "on"

# Popup dimensions (default: 80% width, 70% height)
set -g @tpm-fzf-popup-width "80%"
set -g @tpm-fzf-popup-height "70%"
```

## Plugin Status Legend

- **[pending]** - New plugin in tmux.conf, not yet installed
- **[installed]** - Plugin is installed and working
- **[orphaned]** - Plugin is installed but no longer in tmux.conf
- **[available]** - Available from TPM plugin repository

## Project Structure

```
tpm-fzf/
├── bin/
│   └── fzf-plugins          # Main entry point
├── bindings/
│   └── install              # Key binding setup
├── lib/
│   ├── plugin_functions.sh  # Core plugin helper functions
│   └── utility.sh           # Utility functions
├── scripts/
│   ├── plugin_list.sh       # Main fzf interface
│   ├── plugin_preview.sh    # Preview functionality
│   ├── plugin_delete.sh     # Delete action
│   ├── plugin_install_selected.sh  # Install action
│   ├── plugin_source.sh     # Source action
│   ├── plugin_reload.sh     # Reload helper
│   ├── plugin_update.sh     # Update action
│   ├── refresh_available.sh # Refresh available plugins
│   └── variables.sh         # Configuration
├── tests/
│   └── test_plugin_list.sh  # Tests
├── thoughts/
│   └── plans/              # Implementation plans
└── README.md
```

## Error Handling

If TPM is not installed, tpm-fzf will display an error message:

```
tpm-fzf: TPM (tmux-plugins/tpm) is required but not found
Install TPM: https://github.com/tmux-plugins/tpm
```

## License

MIT License - See LICENSE.md for details.

## Credits

- [tpm](https://github.com/tmux-plugins/tpm) - Tmux Plugin Manager
- [fzf](https://github.com/junegunn/fzf) - Fuzzy finder
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer