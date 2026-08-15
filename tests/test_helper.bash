PLUGIN_DIR=$(cd "$BATS_TEST_DIRNAME/.." && pwd)

setup_tmux_fixture() {
    TEST_ROOT=$BATS_TEST_TMPDIR/fixture
    SOCKET_NAME=tmux-anchor-window-name-$BATS_TEST_NUMBER-$$
    ANCHOR_MARKER=.tmux-anchor-window-name-test-$BATS_TEST_NUMBER-$$

    mkdir -p "$TEST_ROOT/project # one/.git" "$TEST_ROOT/project # one/$ANCHOR_MARKER"
    mkdir -p "$TEST_ROOT/project # one/src/deep" "$TEST_ROOT/plain"
    mkdir -p "$TEST_ROOT/outer/$ANCHOR_MARKER" "$TEST_ROOT/outer/inner/.venv"
    mkdir -p "$TEST_ROOT/outer/inner/src" "$TEST_ROOT/worktree/src"
    printf 'gitdir: elsewhere\n' >"$TEST_ROOT/worktree/.git"

    printf '%s\n' \
        "set -g @tmux-anchor-window-name-anchors 'dir:.git'" \
        "run-shell '$PLUGIN_DIR/tmux-anchor-window-name.tmux'" \
        >"$TEST_ROOT/tmux.conf"
}

teardown_tmux_fixture() {
    tmux -L "$SOCKET_NAME" kill-server 2>/dev/null || true
}

tmux_test() {
    tmux -L "$SOCKET_NAME" "$@"
}

start_session() {
    start_directory=$1
    shift
    (($# > 0)) || set -- sh
    tmux_test -f "$TEST_ROOT/tmux.conf" new-session -d -s test \
        -c "$start_directory" "$@"
    WINDOW_ID=$(tmux_test display-message -p -t test '#{window_id}')
    # Consumed by the Bats files that load this helper.
    # shellcheck disable=SC2034
    PANE_ID=$(tmux_test display-message -p -t "$WINDOW_ID" '#{pane_id}')
}

window_name() {
    tmux_test display-message -p -t "$1" '#{window_name}'
}

wait_for_name() {
    target=$1
    expected=$2
    attempts=0
    actual=

    while ((attempts < 80)); do
        actual=$(window_name "$target")
        [[ $actual == "$expected" ]] && return 0
        ((attempts += 1))
        sleep 0.05
    done

    printf 'expected window name "%s", got "%s"\n' "$expected" "$actual" >&2
    return 1
}

assert_stable_name() {
    target=$1
    expected=$2

    for _ in {1..5}; do
        sleep 0.05
        actual=$(window_name "$target")
        [[ $actual == "$expected" ]] || {
            printf 'expected stable window name "%s", got "%s"\n' "$expected" "$actual" >&2
            return 1
        }
    done
}

assert_automatic_rename() {
    target=$1
    expected=$2
    actual=$(tmux_test show-options -v -w -t "$target" automatic-rename)
    [[ $actual == "$expected" ]] || {
        printf 'expected automatic-rename %s, got %s\n' "$expected" "$actual" >&2
        return 1
    }
}

start_shell_window() {
    shell_name=$1
    shell_command=$2
    result=$(tmux_test new-window -d -P -F '#{window_id} #{pane_id}' \
        -c "$TEST_ROOT/plain" "$shell_command")
    SHELL_WINDOW=${result%% *}
    SHELL_PANE=${result#* }
    wait_for_name "$SHELL_WINDOW" "$shell_name"
}

assert_shell_cd_updates_name() {
    source_command=$1
    tmux_test send-keys -t "$SHELL_PANE" "$source_command" Enter
    tmux_test send-keys -t "$SHELL_PANE" \
        "cd '$TEST_ROOT/project # one/src/deep'" Enter
    wait_for_name "$SHELL_WINDOW" 'project # one'
}
