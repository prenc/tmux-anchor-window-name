# Update the tmux window after Bash changes its working directory.

__tmux_anchor_window_name_update() {
    if [[ ${__tmux_anchor_window_name_last_pwd+x} == x &&
          $__tmux_anchor_window_name_last_pwd == "$PWD" ]]; then
        return 0
    fi
    __tmux_anchor_window_name_last_pwd=$PWD

    [[ -n ${TMUX_PANE:-} ]] || return 0

    local plugin_dir
    plugin_dir=$(command tmux show-options -gqv @tmux-anchor-window-name-plugin-path 2>/dev/null)
    [[ -x $plugin_dir/scripts/update-window-name ]] || return 0

    command "$plugin_dir/scripts/update-window-name" "$TMUX_PANE"
}

__tmux_anchor_window_name_install_bash_hook() {
    local declaration entry
    declaration=$(declare -p PROMPT_COMMAND 2>/dev/null || true)

    if [[ $declaration == 'declare -a '* ]]; then
        for entry in "${PROMPT_COMMAND[@]}"; do
            [[ $entry == __tmux_anchor_window_name_update ]] && return 0
        done
        PROMPT_COMMAND+=(__tmux_anchor_window_name_update)
    elif [[ ${PROMPT_COMMAND:-} != *'__tmux_anchor_window_name_update'* ]]; then
        # This branch is reached only when PROMPT_COMMAND is not an array.
        # shellcheck disable=SC2128,SC2178
        PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}__tmux_anchor_window_name_update"
    fi
}

__tmux_anchor_window_name_install_bash_hook
__tmux_anchor_window_name_update
