# Agent-written helpers: `just agent <recipe>`, listed alone by `just agent`.
#
# Scripts that generalize a command pattern agents kept re-typing. Same
# contract as the root .justfile -- one line of dispatch plus a one-line
# summary per recipe; logic lives in the script beside this file. Any
# language, unlike flake/scripts/ -- see AGENTS.md "Before you start".
#
# Recipes in a module run from this directory, not the caller's: a script
# that takes paths gets `cd "{{invocation_directory()}}"` first. `repo`
# points at the root. Positional arguments keep `"a b"` as one argument
# (use "$@" in the recipe line, not {{args}}).

set positional-arguments

repo    := justfile_directory()
scripts := source_directory()

_default:
    @just --list agent

# Command patterns agents re-type across sessions and hosts: `export`, `setup`
recurring *args:
    @{{scripts}}/recurring.py {{args}}

# Several files/ranges/dirs in one call, a header each: show [-n] path[:A-B]...
show *specs:
    @cd "{{invocation_directory()}}" && "{{scripts}}/show.sh" "$@"

# `just preflight`, one line per step; on failure, that step's tail
preflight-brief:
    @"{{scripts}}/preflight-brief.sh"

# Wait for CI, then gate a PR (CLEAN, base experimental) and print the ask
ship-ready pr:
    @cd "{{invocation_directory()}}" && "{{scripts}}/ship.py" ready "$@"

# On a yes only: re-gate, merge (rebase/merge by commit count), clean up
ship-land pr:
    @cd "{{invocation_directory()}}" && "{{scripts}}/ship.py" land "$@"

# Commit exactly these paths, message on stdin, trailer: commit [--agent X] -- paths
commit *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/ship.py" commit "$@"

# Open the PR for this branch (push -u if needed): pr <body-file> [--title T] [--edit N]
pr *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/ship.py" pr "$@"

# Per-task worktrees: new <branch> [<base>] [--root D] | prune [--yes] [--root D]
worktree *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/worktree.py" "$@"

# preflight-brief on each commit in a throwaway worktree: preflight-each [<range>]
preflight-each *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/preflight-each.sh" "$@"

# Fetch, then branch/dirty/commits/diff-stat vs origin/experimental and the PR: where [<pr>]
where *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/where.py" "$@"
