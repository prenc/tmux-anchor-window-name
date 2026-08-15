#!/usr/bin/env bats

setup() {
    PLUGIN_DIR=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "Bash string PROMPT_COMMAND is preserved and hook registration is idempotent" {
    run bash --noprofile --norc -c \
        "PROMPT_COMMAND='existing-command'; . '$PLUGIN_DIR/shell/tmux-anchor-window-name.bash'; . '$PLUGIN_DIR/shell/tmux-anchor-window-name.bash'; printf '%s' \"\$PROMPT_COMMAND\""

    [[ $status -eq 0 ]]
    [[ $output == 'existing-command;__tmux_anchor_window_name_update' ]]
}

@test "Bash array PROMPT_COMMAND is preserved and hook registration is idempotent" {
    run bash --noprofile --norc -c \
        "PROMPT_COMMAND=(existing-command); . '$PLUGIN_DIR/shell/tmux-anchor-window-name.bash'; . '$PLUGIN_DIR/shell/tmux-anchor-window-name.bash'; declare -p PROMPT_COMMAND"

    [[ $status -eq 0 ]]
    [[ $output == *'[0]="existing-command"'* ]]
    [[ $output == *'[1]="__tmux_anchor_window_name_update"'* ]]
    [[ $output != *'[2]='* ]]
}

@test "Zsh chpwd hook registration is idempotent" {
    command -v zsh >/dev/null 2>&1 || skip 'zsh is not installed'
    run zsh -f -c \
        ". '$PLUGIN_DIR/shell/tmux-anchor-window-name.zsh'; . '$PLUGIN_DIR/shell/tmux-anchor-window-name.zsh'; print -rl -- \$chpwd_functions"

    [[ $status -eq 0 ]]
    [[ $(printf '%s\n' "$output" | grep -c '^__tmux_anchor_window_name_update$') -eq 1 ]]
}

@test "Fish PWD hook can be sourced repeatedly" {
    command -v fish >/dev/null 2>&1 || skip 'fish is not installed'
    run fish --no-config -c \
        "source '$PLUGIN_DIR/shell/tmux-anchor-window-name.fish'; source '$PLUGIN_DIR/shell/tmux-anchor-window-name.fish'"

    [[ $status -eq 0 ]]
}
