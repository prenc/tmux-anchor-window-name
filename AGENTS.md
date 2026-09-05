# Repository Instructions

This repository contains a tmux plugin that names a window after the nearest
parent folder containing a configured anchor. Preserve the plugin's small,
dependency-light design and test behavior through real tmux processes whenever
possible.

## Repository layout

```text
.
├── .github/
│   └── workflows/
│       └── tests.yml                 # CI: syntax, ShellCheck, and Bats
├── shell/
│   ├── tmux-anchor-window-name.bash  # Bash PWD integration via PROMPT_COMMAND
│   ├── tmux-anchor-window-name.fish  # Fish integration via PWD event
│   └── tmux-anchor-window-name.zsh   # Zsh integration via chpwd
├── scripts/
│   ├── folder-name                   # Pure filesystem anchor lookup
│   └── update-window-name            # Reads tmux state and renames one window
├── tests/
│   ├── folder-name.bats              # Anchor parser/filesystem tests
│   ├── shell-hooks.bats              # Hook registration and idempotency tests
│   ├── test_helper.bash              # Isolated tmux fixture and assertions
│   ├── tmux-integration.bats         # End-to-end tests using real tmux servers
│   └── run.sh                        # Convenience wrapper around Bats
├── LICENSE
├── README.md                         # User-facing installation and reference
└── tmux-anchor-window-name.tmux      # TPM entry point and tmux hook setup
```

## Architecture

`tmux-anchor-window-name.tmux` is the plugin entry point. It records its path in
`@tmux-anchor-window-name-plugin-path`, installs indexed tmux hooks, and updates
windows that already exist. Hook index `900` belongs to this plugin. Keep hooks
indexed so reloading is idempotent and does not replace user or plugin hooks.

`scripts/folder-name` is independent of tmux. Starting at a directory, it walks
toward `/` and prints the basename of the first folder containing a matching
anchor. It exits with status `1` and no output when nothing matches.

`scripts/update-window-name` is the tmux boundary. It:

1. Ignores missing and inactive panes.
2. Resolves the pane's window and current path.
3. Exits when `automatic-rename` is off, preserving manual names.
4. Calls `scripts/folder-name` with the configured anchors and separator.
5. Uses the folder basename when matched, otherwise the active command.
6. Escapes `#` before storing a literal `automatic-rename-format`.

tmux does not emit an event when a shell runs `cd`. Files under `shell/` bridge
that gap. They must be safe outside tmux and safe to source repeatedly.

## Configuration contract

The public tmux options are:

```tmux
set -g @tmux-anchor-window-name-anchors 'dir:.git'
set -g @tmux-anchor-window-name-separator ','
```

Anchors use `type:marker` syntax. Supported types are:

- `dir`: a directory or symlink resolving to a directory
- `file`: a regular file or symlink resolving to a regular file
- `any`: any existing entry, including a broken symlink

The separator is a nonempty literal string other than `:`. Empty or `:` values
fall back to `,`. Whitespace around separators is ignored. Marker names may
contain whitespace but cannot contain the configured separator.

The only default anchor is `dir:.git`. Do not silently change this to
`any:.git`: `.git` files used by Git worktrees are intentionally opt-in.

## Behavioral invariants

- The nearest matching parent folder wins.
- The active pane determines an automatically managed window's name.
- Closing or selecting panes updates the name to follow the new active pane.
- An inactive pane must never rename its window.
- No matching anchor falls back to `#{pane_current_command}`.
- `rename-window` and `new-window -n` names always prevail.
- Existing indexed tmux hooks must not be overwritten.
- Reloading the plugin and shell integrations must be idempotent.
- Folder names containing spaces or `#` must work.
- The core scripts remain POSIX `sh`; shell-specific syntax belongs in
  `shell/` or the Bats test helpers.

## Shell integrations

- Bash appends one callback to either the string or array form of
  `PROMPT_COMMAND`, preserves existing callbacks, and avoids tmux calls when
  `PWD` has not changed.
- Zsh uses an idempotent `add-zsh-hook chpwd` callback.
- Fish defines a function bound to changes of `PWD`.

All integrations query `@tmux-anchor-window-name-plugin-path` rather than
assuming a TPM installation directory.

## Running tests

[bats-core](https://github.com/bats-core/bats-core) is required. Run everything
from the repository root:

```sh
./tests/run.sh
```

Equivalent direct invocation:

```sh
bats --print-output-on-failure tests
```

Run one file or select tests while developing:

```sh
bats tests/folder-name.bats
bats tests/tmux-integration.bats
bats --filter 'manual name' tests
```

The integration tests start a unique tmux server with `tmux -L`, create all
fixtures under Bats' temporary directory, and kill the server during teardown.
Never target or modify the user's normal tmux server in tests. Bash is required;
Zsh and Fish cases skip when those shells are unavailable. CI installs all three
shells and therefore runs every case.

## Required validation

Before handing off a change, run the same checks as CI:

```sh
sh -n tmux-anchor-window-name.tmux scripts/folder-name scripts/update-window-name tests/run.sh
bash -n shell/tmux-anchor-window-name.bash tests/test_helper.bash
zsh -n shell/tmux-anchor-window-name.zsh
fish -n shell/tmux-anchor-window-name.fish
shellcheck tmux-anchor-window-name.tmux scripts/folder-name scripts/update-window-name tests/run.sh
shellcheck --shell=bash shell/tmux-anchor-window-name.bash tests/test_helper.bash
bats --print-output-on-failure tests
```

If Zsh or Fish is unavailable locally, state which syntax or integration checks
were skipped. Do not claim complete validation when Bats skipped those cases.

## Test expectations for changes

- Parser or anchor changes require focused cases in `folder-name.bats` and at
  least one end-to-end case when tmux-facing behavior changes.
- Hook or rename changes require real tmux tests in `tmux-integration.bats`.
- Shell integration changes require both registration/idempotency coverage in
  `shell-hooks.bats` and a real `cd` test inside that shell under tmux.
- Bug fixes should include a regression test that fails before the fix.
- Keep each Bats test independent; use the shared fixture instead of relying on
  test order or the user's filesystem and tmux configuration.

## Documentation and compatibility

Update `README.md` whenever public options, installation steps, requirements,
defaults, or shell integration behavior changes. Keep examples valid for both
TPM and a local checkout.

Avoid adding runtime dependencies without a strong reason. Test-only tools are
acceptable when installed in CI. Preserve executable bits on the plugin entry
point, scripts, and `tests/run.sh`.
