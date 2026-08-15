#!/bin/sh

set -eu

test_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

if ! command -v bats >/dev/null 2>&1; then
    printf 'bats-core is required: https://github.com/bats-core/bats-core\n' >&2
    exit 127
fi

exec bats "$test_dir"
