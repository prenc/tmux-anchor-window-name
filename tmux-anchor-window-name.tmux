#!/bin/sh

plugin_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
update_script=$plugin_dir/scripts/update-window-name
update_hook="run-shell '\"$update_script\" #{q:pane_id}'"

tmux set-option -gq @tmux-anchor-window-name-plugin-path "$plugin_dir"

# Indexed hooks make reloading the plugin idempotent and avoid replacing hooks
# installed by the user's configuration or other plugins.
tmux set-hook -g 'after-new-window[900]' "$update_hook"
tmux set-hook -g 'after-new-session[900]' "$update_hook"
tmux set-hook -g 'window-pane-changed[900]' "$update_hook"

# Apply the naming rule to windows that existed before the plugin was loaded.
tmux list-panes -a -F '#{?pane_active,#{pane_id},}' |
while IFS= read -r pane_id; do
    [ -n "$pane_id" ] && "$update_script" "$pane_id"
done
