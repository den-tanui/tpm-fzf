# tpm-fzf configuration block markers
config_start="# tpm-fzf configuration"
config_end="# tpm-fzf end of configuration"

# tpm-fzf key binding
key_option="@tpm-fzf-key"
default_key="i"

# TPM plugin path (where tpm itself is installed)
tpm_plugin_option="@tpm-fzf-tpm-plugin"
default_tpm_plugin="tmux-plugins/tpm"

# Plugin install directory (where plugins are installed)
plugin_dir_option="@tpm-fzf-plugin-dir"
default_plugin_dir="~/.tmux/plugins/"

# tmux.conf path to use
tmux_conf_option="@tpm-fzf-tmux-conf"
default_tmux_conf="~/.tmux.conf"

# Plugin grouping options
grouping_enabled_option="@tpm-fzf-grouping-enabled"
default_grouping_enabled="on"

grouping_start_marker_option="@tpm-fzf-grouping-start"
default_grouping_start="#TPM plugins"

grouping_end_marker_option="@tpm-fzf-grouping-end"
default_grouping_end="#End of plugin list"

# Dependencies
SUPPORTED_TMUX_VERSION="1.9"
REQUIRED_TPM_VERSION="2.0"