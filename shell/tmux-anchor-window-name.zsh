# Update the tmux window after Zsh changes its working directory.

__tmux_anchor_window_name_update() {
    [[ -n ${TMUX_PANE:-} ]] || return 0

    local plugin_dir
    plugin_dir=$(command tmux show-options -gqv @tmux-anchor-window-name-plugin-path 2>/dev/null)
    [[ -x $plugin_dir/scripts/update-window-name ]] || return 0

    command "$plugin_dir/scripts/update-window-name" "$TMUX_PANE"
}

autoload -Uz add-zsh-hook
add-zsh-hook -d chpwd __tmux_anchor_window_name_update 2>/dev/null
add-zsh-hook chpwd __tmux_anchor_window_name_update

__tmux_anchor_window_name_update
