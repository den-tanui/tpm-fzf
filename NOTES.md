1. How we should find and install available plugins

- extract all the urls from <https://raw.githubusercontent.com/tmux-plugins/list/master/README.md> and save them as a config file, user's can add and remove plugins from the list. (this is not part of our code, you should do this yourself and create a ready config file before we proceed)
- the new command will parse this config file and show list [available]
- the config file can contain only urls, the script should be able to parse it and extract plugin name in the form of author/repo.
- [installed] already lists plugins with this format. keep [orphaned] plugin list as repo only to avoid overhead of finding remote repo. [available] plugins should have the author/repo format after parsing the config file.
- only install a plugin format available if the readme in the preview loads successfully i.e the remote repo exists and is reachable.

2. The scripts we need

- plugin_list should stay the same + the preview script - preserve the fzf commands
- install specific selected plugin. i.e add it to tmux.conf and clone the repo into plugin dir.
- remove/delete specific plugins - i.e comment out a plugin in tmux.conf and delete the plugin dir.
- update script that adapts tpm's update script to only update the selected plugins.

3. utility scripts

- script to find tpm path, or clone it to plugins dir, and check if it's sourced in tmux.conf
- script to parse tmux.conf and group all "set -g @plugins" even commented ones and making sure tpm is sourced at the end of tmux.conf. install script should add new plugins to this block.
- messaging utility to display messages and get input from user with tmux eg if errors occur:
  - tmux.conf not found, path to tmux.conf:
  - tpm not found, [1] enter path [2] install it for me
  - plugin installed/updated/removed notifications
  - etc
  - user input should be able to update tmux options
  - add other options you think are relevant to the plugin
- sanity/requirements checks - validate tpm_fzf specific configuration from tmux.conf - check if git clone command exists and is in path and is executable
- if errors use messaging utility to prompt user/show errors
- script to parse urls in config files and tmux options. when parsing user provided urls, check to see if there's a .tmux file in the repo i.e it's a tmux plugin, prompt user if errors like a repo not being a tmux plugin or unreachable.
- a script to check if we're online and github is reachable - if not, just load local plugins - this script should be none blocking i.e the fzf list loads first, if online the list is updated with available plugins.

3. tpm dependent scripts

- we'll call the following scripts directly from tpm directory:
  - clean_plugins
  - install_plugins
  - update_plugin : we'll call this script with "all" as argument to update all plugins
  - source plugins

4. fzf

- keybindings that call our scripts/runs command:
- install specific plugin from available
- remove specific plugin
- clean specific plugin from [orphaned]
- refresh list using (+reload) pattern
- reload tmux.conf

-keybindings that call tpm scripts directly:

- install_plugins
- clean_plugins
- update_plugins - call this with "all" to update all plugins

- UI improvements.
  - dynamically change the actions that can be taken on a plugin i.e for [installed] plugins show remove and clean options, [available] should have install option only if the preview window loaded successfully etc. bindings from tpm should always be available. look at m0squdev/apf to see how its done.
- implement the same technique as apf to hide/show help i.e bindings
- keep the ansi color codes and color for preview
- remove multi other scripts should accept only one plugin from selection.
- bindings that call tpm scripts don't take the selections as arguments as they work on all plugins etc
- should not echo to shell, the legend from plugin_list should be displayed in the help menu we can trigger with ctrl-h like apf.
- show online status. get output from the online status script.

5. tpm_fzf.tmux file should contain
   popup command = tmux display-popup -w 80% -h 80% -B -E bash scripts/plugin_list.sh

- configured keybinding to run the popup command
  -configuration for popup dimensions.
- configuration for tpm path, tmux.conf path, plugin directory, git clone command eg "gh repo clone"
- additional repos to check for available plugins, and > [!TIP]ath to config file containing list of urls of plugins.
- set up variables.sh to get and set these tmux options.

6. research

- what you should research:
- tmux plugin architecture
- tpm scripts and how it implements them - we're going to adapt most of them
- fzf advanced patterns

sources:

- /home/.config/tmux/plugins/tpm
- /home/opt/fzf/apf
- /home/projects/hacking/Hacking/fzf - some notes
- /home/opt/fzf/ - some fzf projects, actual fzf source code and docs, etc
