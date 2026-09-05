#!/usr/bin/env bats

load test_helper

setup() {
    setup_tmux_fixture
}

teardown() {
    teardown_tmux_fixture
}

@test "initial window uses the nearest .git folder and escapes hash characters" {
    start_session "$TEST_ROOT/project # one/src/deep" sh
    wait_for_name "$WINDOW_ID" 'project # one'
}

@test "folder name with a doubled hash is stored literally by the rename step" {
    start_session "$TEST_ROOT/plain" sh
    tmux_test send-keys -t "$PANE_ID" "cd '$TEST_ROOT/hash##42/src'" Enter
    wait_for_path "$PANE_ID" "$TEST_ROOT/hash##42/src"
    split_pane=$(tmux_test split-window -P -F '#{pane_id}' \
        -t "$WINDOW_ID" -c "$TEST_ROOT/plain" sh)
    wait_for_name "$WINDOW_ID" sh
    tmux_test select-pane -t "$PANE_ID"
    assert_immediate_name "$WINDOW_ID" sh 'hash##42'
    wait_for_name "$WINDOW_ID" 'hash##42'
}

@test "folder name with a format job is stored literally and spawns no job" {
    rm -f "$PWD/tawn-job-marker"
    start_session "$TEST_ROOT/plain" sh
    tmux_test send-keys -t "$PANE_ID" \
        "cd '$TEST_ROOT/job#(touch tawn-job-marker)/src'" Enter
    wait_for_path "$PANE_ID" "$TEST_ROOT/job#(touch tawn-job-marker)/src"
    split_pane=$(tmux_test split-window -P -F '#{pane_id}' \
        -t "$WINDOW_ID" -c "$TEST_ROOT/plain" sh)
    wait_for_name "$WINDOW_ID" sh
    tmux_test select-pane -t "$PANE_ID"
    assert_immediate_name "$WINDOW_ID" sh 'job#(touch tawn-job-marker)'
    # A registered format job would fork a shell child almost immediately;
    # give a spurious job a chance to run before asserting it never started.
    sleep 0.5
    [[ ! -e "$PWD/tawn-job-marker" ]]
    [[ ! -e "$TEST_ROOT/tawn-job-marker" ]]
}

@test "window falls back to the active command when no anchor matches" {
    start_session "$TEST_ROOT/plain" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors "dir:$ANCHOR_MARKER"
    "$PLUGIN_DIR/scripts/update-window-name" "$PANE_ID"
    wait_for_name "$WINDOW_ID" sh
}

@test "custom separator is used by the tmux updater" {
    start_session "$TEST_ROOT/project # one/src" sh
    tmux_test set-option -g @tmux-anchor-window-name-separator '|'
    tmux_test set-option -g @tmux-anchor-window-name-anchors 'dir:missing|dir:.git'
    tmux_test rename-window -t "$WINDOW_ID" before-update
    tmux_test set-window-option -t "$WINDOW_ID" automatic-rename on
    "$PLUGIN_DIR/scripts/update-window-name" "$PANE_ID"
    wait_for_name "$WINDOW_ID" 'project # one'
}

@test "selecting panes follows the newly active pane" {
    start_session "$TEST_ROOT/project # one/src" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors "dir:$ANCHOR_MARKER"
    plain_pane=$(tmux_test split-window -d -P -F '#{pane_id}' \
        -t "$WINDOW_ID" -c "$TEST_ROOT/plain" sh)

    tmux_test select-pane -t "$plain_pane"
    wait_for_name "$WINDOW_ID" sh
    tmux_test select-pane -t "$PANE_ID"
    wait_for_name "$WINDOW_ID" 'project # one'
}

@test "calling the updater for an inactive pane does not rename the window" {
    start_session "$TEST_ROOT/project # one/src" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors "dir:$ANCHOR_MARKER"
    plain_pane=$(tmux_test split-window -d -P -F '#{pane_id}' \
        -t "$WINDOW_ID" -c "$TEST_ROOT/plain" sh)

    "$PLUGIN_DIR/scripts/update-window-name" "$plain_pane"
    assert_stable_name "$WINDOW_ID" 'project # one'
}

@test "closing the active pane follows the pane that takes over" {
    start_session "$TEST_ROOT/project # one/src" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors "dir:$ANCHOR_MARKER"
    plain_pane=$(tmux_test split-window -d -P -F '#{pane_id}' \
        -t "$WINDOW_ID" -c "$TEST_ROOT/plain" sh)

    tmux_test kill-pane -t "$PANE_ID"
    wait_for_name "$WINDOW_ID" sh
    [[ $(tmux_test display-message -p -t "$WINDOW_ID" '#{pane_id}') == "$plain_pane" ]]
}

@test "nearest configured anchor wins through the tmux update path" {
    start_session "$TEST_ROOT/plain" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors \
        "dir:$ANCHOR_MARKER,dir:.venv"
    nested_window=$(tmux_test new-window -d -P -F '#{window_id}' \
        -c "$TEST_ROOT/outer/inner/src" sh)
    wait_for_name "$nested_window" inner
}

@test "manual name survives active pane closure" {
    start_session "$TEST_ROOT/project # one/src" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors "dir:$ANCHOR_MARKER"
    plain_pane=$(tmux_test split-window -d -P -F '#{pane_id}' \
        -t "$WINDOW_ID" -c "$TEST_ROOT/plain" sh)
    tmux_test rename-window -t "$WINDOW_ID" manual-name
    tmux_test kill-pane -t "$PANE_ID"

    assert_stable_name "$WINDOW_ID" manual-name
    assert_automatic_rename "$WINDOW_ID" off
    [[ -n $plain_pane ]]
}

@test "name supplied to new-window prevails" {
    start_session "$TEST_ROOT/plain" sh
    explicit_window=$(tmux_test new-window -d -P -F '#{window_id}' \
        -n explicit-name -c "$TEST_ROOT/project # one/src" sh)

    assert_stable_name "$explicit_window" explicit-name
    assert_automatic_rename "$explicit_window" off
}

@test "file anchor names a Git worktree" {
    start_session "$TEST_ROOT/plain" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors file:.git
    worktree_window=$(tmux_test new-window -d -P -F '#{window_id}' \
        -c "$TEST_ROOT/worktree/src" sh)
    wait_for_name "$worktree_window" worktree
}

@test "plugin hook coexists with an existing indexed hook" {
    printf '%s\n' \
        "set -g @tmux-anchor-window-name-anchors 'dir:.git'" \
        "set-hook -g 'window-pane-changed[42]' 'set-option -g @test-user-hook fired'" \
        "run-shell '$PLUGIN_DIR/tmux-anchor-window-name.tmux'" \
        >"$TEST_ROOT/tmux.conf"
    start_session "$TEST_ROOT/project # one/src" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors "dir:$ANCHOR_MARKER"
    plain_pane=$(tmux_test split-window -d -P -F '#{pane_id}' \
        -t "$WINDOW_ID" -c "$TEST_ROOT/plain" sh)
    tmux_test select-pane -t "$plain_pane"

    [[ $(tmux_test show-option -gqv @test-user-hook) == fired ]]
    wait_for_name "$WINDOW_ID" sh
}

@test "reloading plugin does not duplicate its indexed hooks" {
    start_session "$TEST_ROOT/project # one/src" sh
    tmux_test run-shell "$PLUGIN_DIR/tmux-anchor-window-name.tmux"

    run tmux_test show-hooks -g window-pane-changed
    [[ $status -eq 0 ]]
    [[ $(printf '%s\n' "$output" | grep -c 'window-pane-changed\[900\]') -eq 1 ]]
}

@test "loading plugin names windows that already exist" {
    printf '%s\n' >"$TEST_ROOT/empty.conf"
    tmux_test -f "$TEST_ROOT/empty.conf" new-session -d -s test \
        -c "$TEST_ROOT/project # one/src" sh
    WINDOW_ID=$(tmux_test display-message -p -t test '#{window_id}')
    tmux_test run-shell "$PLUGIN_DIR/tmux-anchor-window-name.tmux"

    wait_for_name "$WINDOW_ID" 'project # one'
}

@test "Bash hook updates after cd and preserves existing PROMPT_COMMAND" {
    start_session "$TEST_ROOT/plain" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors "dir:$ANCHOR_MARKER"
    start_shell_window bash 'bash --noprofile --norc'
    tmux_test send-keys -t "$SHELL_PANE" "PROMPT_COMMAND='printf \"\"'" Enter
    assert_shell_cd_updates_name \
        ". '$PLUGIN_DIR/shell/tmux-anchor-window-name.bash'"
}

@test "Zsh hook updates after cd" {
    command -v zsh >/dev/null 2>&1 || skip 'zsh is not installed'
    start_session "$TEST_ROOT/plain" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors "dir:$ANCHOR_MARKER"
    start_shell_window zsh 'zsh -f'
    assert_shell_cd_updates_name \
        ". '$PLUGIN_DIR/shell/tmux-anchor-window-name.zsh'"
}

@test "Fish hook updates after cd" {
    command -v fish >/dev/null 2>&1 || skip 'fish is not installed'
    start_session "$TEST_ROOT/plain" sh
    tmux_test set-option -g @tmux-anchor-window-name-anchors "dir:$ANCHOR_MARKER"
    start_shell_window fish 'fish --no-config'
    assert_shell_cd_updates_name \
        "source '$PLUGIN_DIR/shell/tmux-anchor-window-name.fish'"
}
