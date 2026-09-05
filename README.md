# tmux-anchor-window-name

[![Tests](https://github.com/prenc/tmux-anchor-window-name/actions/workflows/tests.yml/badge.svg)](https://github.com/prenc/tmux-anchor-window-name/actions/workflows/tests.yml)
[![tmux plugin](https://img.shields.io/badge/tmux-plugin-1BB91F?logo=tmux)](https://github.com/tmux/tmux)
[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Give tmux windows stable, useful names based on the folders where you work.

`tmux-anchor-window-name` walks upward from the active pane, finds the nearest
folder containing a configured anchor, and uses that folder's name for the
window. Inside any subdirectory of `~/code/my-project/.git/`, your window is
simply named `my-project`.

No matching anchor? The window falls back to the active command. Named a window
yourself? Your manual name always wins.

## Features

- Names windows after the nearest anchored parent folder
- Uses a `.git/` directory as the sensible zero-configuration default
- Supports directory, file, and type-agnostic anchors
- Handles several project types at once, such as Git, Python, and custom roots
- Updates after `cd` in Bash, Zsh, and Fish
- Follows the active pane when panes are selected or closed
- Preserves names set with `rename-window` or `new-window -n`
- Falls back to the active pane's command outside an anchored folder
- Supports custom and multi-character anchor separators
- Coexists with existing indexed tmux hooks
- Ships with real isolated-tmux integration tests

## Installation

### TPM

Add the plugin before TPM's final `run` line in `tmux.conf`:

```tmux
set -g @plugin 'prenc/tmux-anchor-window-name'
```

Reload tmux and press `prefix + I` to install it.

### Local checkout

To use a local checkout directly:

```tmux
run-shell '~/tmux-anchor-window-name/tmux-anchor-window-name.tmux'
```

If your checkout is elsewhere, replace `~/tmux-anchor-window-name` with its
path.

Then reload your configuration:

```sh
tmux source-file ~/.tmux.conf
```

## Install the shell integration

tmux does not emit an event when a shell changes directory. Enable the
integration for your shell after installing the plugin to update names after
`cd`.

Fish automatically loads files from `~/.config/fish/conf.d`. Bash and Zsh do
not have an equivalent universally loaded directory, so add the appropriate
line to the shell's startup file.

### Bash

Run:

```bash
touch "$HOME/.bashrc"
line='source "$HOME/.tmux/plugins/tmux-anchor-window-name/shell/tmux-anchor-window-name.bash"'
grep -qxF "$line" "$HOME/.bashrc" || printf '\n%s\n' "$line" >> "$HOME/.bashrc"
source "$HOME/.bashrc"
```

### Zsh

Run:

```zsh
zshrc=${ZDOTDIR:-$HOME}/.zshrc
touch "$zshrc"
line='source "$HOME/.tmux/plugins/tmux-anchor-window-name/shell/tmux-anchor-window-name.zsh"'
grep -qxF "$line" "$zshrc" || printf '\n%s\n' "$line" >> "$zshrc"
source "$zshrc"
```

### Fish

Link the integration into Fish's `conf.d` directory:

```fish
mkdir -p "$HOME/.config/fish/conf.d"
ln -s \
    "$HOME/.tmux/plugins/tmux-anchor-window-name/shell/tmux-anchor-window-name.fish" \
    "$HOME/.config/fish/conf.d/tmux-anchor-window-name.fish"
source "$HOME/.config/fish/conf.d/tmux-anchor-window-name.fish"
```

For the example local checkout above, replace
`~/.tmux/plugins/tmux-anchor-window-name` in the shell-integration commands
with `~/tmux-anchor-window-name`.

## Configuration

Put options before the plugin is loaded. The defaults require no configuration.

### Choose anchors

An anchor has the form `type:marker`. Combine anchors in a comma-separated list:

```tmux
set -g @tmux-anchor-window-name-anchors 'dir:.git,dir:.venv,file:pyproject.toml,any:.project-root'
```

| Type | Matches |
| --- | --- |
| `dir` | A directory, including a symlink resolving to a directory |
| `file` | A regular file, including a symlink resolving to a file |
| `any` | Any filesystem entry, including a broken symlink |

The default is:

```tmux
set -g @tmux-anchor-window-name-anchors 'dir:.git'
```

This matches normal Git repositories while intentionally excluding Git
worktrees, where `.git` is a file. To support both repositories and worktrees:

```tmux
set -g @tmux-anchor-window-name-anchors 'any:.git'
```

The nearest matching parent wins. If several anchors match the same folder,
their order does not matter because the resulting folder name is identical.

### Change the separator

The separator defaults to a comma:

```tmux
set -g @tmux-anchor-window-name-separator ','
```

It can be any nonempty literal string except `:`, which separates the anchor
type from its marker:

```tmux
set -g @tmux-anchor-window-name-separator '|'
set -g @tmux-anchor-window-name-anchors 'dir:.git|dir:.venv|file:pyproject.toml'
```

Whitespace around separators is ignored. Marker names may contain whitespace,
but cannot contain the configured separator.

## Manual names

tmux disables automatic renaming when you use `rename-window` or pass `-n` to
`new-window`. The plugin respects that state, so manual names survive directory
changes, pane switches, and pane closure.

To return a window to automatic naming:

```sh
tmux set-window-option automatic-rename on
```

Its name will update on the next pane event or directory change.

## Requirements

- tmux
- A POSIX-compatible shell
- `sed`
- Bash, Zsh, or Fish only for that shell's optional `cd` integration
