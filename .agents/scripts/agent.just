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

# `just preflight`, steps run concurrently, one line each; a failing step's tail
preflight-brief:
    @"{{scripts}}/preflight-brief.py"

# Wait for CI, then gate a PR (CLEAN, base experimental) and print the ask
ship-ready pr:
    @cd "{{invocation_directory()}}" && "{{scripts}}/ship.py" ready "$@"

# On a yes only: re-gate, merge (rebase/merge by commit count), clean up
ship-land pr:
    @cd "{{invocation_directory()}}" && "{{scripts}}/ship.py" land "$@"

# Mechanical checks of the mdBook (links, anchors, SUMMARY, stale dates and counts): check | prose
book-lint *args:
    @"{{scripts}}/book_lint.py" "$@"

# A built mdBook as one self-contained HTML file: book-render <mdbook-output-dir> <dest.html>
book-render *args:
    @"{{scripts}}/book_render.py" "$@"

# After `git mv`: rewrite links and path mentions repo-wide; REVIEW lines = code to read
move-refs *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/move_refs.py" "$@"

# Commit exactly these paths, message on stdin, trailer: commit [--agent X] -- paths
commit *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/ship.py" commit "$@"

# Open the PR for this branch (push -u if needed): pr <body-file> [--title T] [--edit N]
pr *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/ship.py" pr "$@"

# Per-task worktrees: new <branch> [<base>] [--root D] | prune [--yes] [--root D]
worktree *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/worktree.py" "$@"

# preflight-brief on each commit, throwaway worktrees: preflight-each [--jobs N] [<range>]
preflight-each *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/preflight-each.py" "$@"

# Fetch, then branch/dirty/commits/diff-stat vs origin/experimental and the PR: where [<pr>]
where *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/where.py" "$@"

# What applies to these paths (default: this branch's diff): lessons [<path>...] [--command C]
lessons *args:
    @cd "{{invocation_directory()}}" && "{{scripts}}/lessons.py" "$@"

# Docs ranked by commits to the paths they cite since their date: doc-drift [--top N]
doc-drift *args:
    @"{{scripts}}/doc_drift.py" "$@"

# Split every doc into N balanced groups, siblings together; exit 1 if any lost: doc-partition [--agents N]
doc-partition *args:
    @"{{scripts}}/doc_partition.py" "$@"
