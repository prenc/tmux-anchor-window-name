function __tmux_anchor_window_name_update --on-variable PWD --description 'Update tmux window name after changing folders'
    status is-interactive; or return 0
    set -q TMUX_PANE; or return 0

    set -l plugin_dir (command tmux show-options -gqv @tmux-anchor-window-name-plugin-path 2>/dev/null)
    test -n "$plugin_dir"; or return 0
    test -x "$plugin_dir/scripts/update-window-name"; or return 0

    command "$plugin_dir/scripts/update-window-name" "$TMUX_PANE"
end

__tmux_anchor_window_name_update
