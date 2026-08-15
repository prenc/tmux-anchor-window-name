#!/usr/bin/env bats

setup() {
    PLUGIN_DIR=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
    FOLDER_NAME=$PLUGIN_DIR/scripts/folder-name
    TEST_ROOT=$BATS_TEST_TMPDIR/fixture
    TEST_ROOT_NAME=$(basename "$TEST_ROOT")

    mkdir -p "$TEST_ROOT/.git"
    mkdir -p "$TEST_ROOT/repository/.git" "$TEST_ROOT/repository/src/deep"
    mkdir -p "$TEST_ROOT/venv-project/.venv" "$TEST_ROOT/venv-project/src"
    mkdir -p "$TEST_ROOT/outer/.git" "$TEST_ROOT/outer/inner/.venv"
    mkdir -p "$TEST_ROOT/outer/inner/src" "$TEST_ROOT/plain/src"
    printf 'gitdir: elsewhere\n' >"$TEST_ROOT/plain/.git"
    printf '[project]\n' >"$TEST_ROOT/plain/pyproject.toml"
    printf 'anchor\n' >"$TEST_ROOT/plain/project anchor"
}

assert_folder_name() {
    expected=$1
    directory=$2
    anchors=${3:-dir:.git}
    separator=${4:-,}

    run "$FOLDER_NAME" "$directory" "$anchors" "$separator"
    [[ $status -eq 0 ]]
    [[ $output == "$expected" ]]
}

@test "default .git directory names a deeply nested project" {
    assert_folder_name repository "$TEST_ROOT/repository/src/deep"
}

@test "nearest matching parent wins" {
    assert_folder_name inner "$TEST_ROOT/outer/inner/src" 'dir:.git,dir:.venv'
}

@test "directory anchor does not match a .git file" {
    assert_folder_name "$TEST_ROOT_NAME" "$TEST_ROOT/plain/src"
}

@test "file anchor matches a .git file" {
    assert_folder_name plain "$TEST_ROOT/plain/src" file:.git
}

@test "any anchor matches files and directories" {
    assert_folder_name plain "$TEST_ROOT/plain/src" any:.git
    assert_folder_name repository "$TEST_ROOT/repository/src" any:.git
}

@test "any anchor matches a broken symbolic link" {
    ln -s missing "$TEST_ROOT/plain/.anchor"
    assert_folder_name plain "$TEST_ROOT/plain/src" any:.anchor
}

@test "dir and file anchors follow symbolic links of the matching type" {
    mkdir "$TEST_ROOT/plain/actual-directory"
    printf 'anchor\n' >"$TEST_ROOT/plain/actual-file"
    ln -s actual-directory "$TEST_ROOT/plain/directory-link"
    ln -s actual-file "$TEST_ROOT/plain/file-link"

    assert_folder_name plain "$TEST_ROOT/plain/src" dir:directory-link
    assert_folder_name plain "$TEST_ROOT/plain/src" file:file-link
}

@test "comma is the default separator" {
    assert_folder_name plain "$TEST_ROOT/plain/src" 'dir:missing,file:pyproject.toml'
}

@test "separator is configurable and may contain multiple characters" {
    assert_folder_name plain "$TEST_ROOT/plain/src" 'dir:missing|file:pyproject.toml' '|'
    assert_folder_name plain "$TEST_ROOT/plain/src" 'dir:missing||file:pyproject.toml' '||'
}

@test "whitespace around separators is ignored" {
    assert_folder_name plain "$TEST_ROOT/plain/src" 'dir:missing,  file:pyproject.toml  '
}

@test "marker names may contain whitespace" {
    assert_folder_name plain "$TEST_ROOT/plain/src" 'file:project anchor'
}

@test "unsupported and malformed anchor specifications are ignored" {
    run "$FOLDER_NAME" "$TEST_ROOT/plain/src" 'unsupported:.git,missing-type'
    [[ $status -eq 1 ]]
    [[ -z $output ]]
}

@test "no matching anchor exits unsuccessfully without output" {
    run "$FOLDER_NAME" "$TEST_ROOT/plain/src" dir:.__missing_anchor__
    [[ $status -eq 1 ]]
    [[ -z $output ]]
}

@test "empty and reserved separators fall back to comma" {
    assert_folder_name plain "$TEST_ROOT/plain/src" 'dir:missing,file:pyproject.toml' ''
    assert_folder_name plain "$TEST_ROOT/plain/src" 'dir:missing,file:pyproject.toml' ':'
}
