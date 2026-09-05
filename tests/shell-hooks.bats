#!/usr/bin/env bats

setup() {
    PLUGIN_DIR=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "Bash string PROMPT_COMMAND is preserved and hook registration is idempotent" {
    run bash --noprofile --norc -c \
        "PROMPT_COMMAND='existing-command'; . '$PLUGIN_DIR/shell/tmux-anchor-window-name.bash'; . '$PLUGIN_DIR/shell/tmux-anchor-window-name.bash'; printf '%s' \"$PROMPT_COMMAND\""

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

@test "Non-interactive source of bash and zsh hooks makes no tmux calls" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '%s\n' \
        '#!/bin/sh' \
        'printf "%s\n" "$*" >> "${TMUX_CALL_LOG:?}"' \
        'exit 0' >"$BATS_TEST_TMPDIR/bin/tmux"
    chmod +x "$BATS_TEST_TMPDIR/bin/tmux"

    BASH_LOG="$BATS_TEST_TMPDIR/tmux-calls-bash.log"
    run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" TMUX="$BATS_TEST_TMPDIR/sock" \
        TMUX_PANE=%0 TMUX_CALL_LOG="$BASH_LOG" \
        bash --noprofile --norc -c ". '$PLUGIN_DIR/shell/tmux-anchor-window-name.bash'"

    [[ $status -eq 0 ]]
    [[ ! -s $BASH_LOG ]]

    if command -v zsh >/dev/null 2>&1; then
        ZSH_LOG="$BATS_TEST_TMPDIR/tmux-calls-zsh.log"
        run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" TMUX="$BATS_TEST_TMPDIR/sock" \
            TMUX_PANE=%0 TMUX_CALL_LOG="$ZSH_LOG" \
            zsh -f -c ". '$PLUGIN_DIR/shell/tmux-anchor-window-name.zsh'"

        [[ $status -eq 0 ]]
        [[ ! -s $ZSH_LOG ]]
    fi
}

@test "Fish PWD hook can be sourced repeatedly" {
    command -v fish >/dev/null 2>&1 || skip 'fish is not installed'
    run fish --no-config -c \
        "source '$PLUGIN_DIR/shell/tmux-anchor-window-name.fish'; source '$PLUGIN_DIR/shell/tmux-anchor-window-name.fish'"

    [[ $status -eq 0 ]]
}
