# Agent-written helpers: `just agent <recipe>`, listed alone by `just agent`.
#
# Scripts that generalize a command pattern agents kept re-typing. Same
# contract as the root .justfile -- one line of dispatch plus a one-line
# summary per recipe; logic lives in the script beside this file. Any
# language, unlike flake/scripts/ -- see AGENTS.md's "Agent scripts" entry.
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

# Command fragments agents re-typed across sessions, from local transcripts
recurring *args:
    @{{scripts}}/recurring.py {{args}}

# Several files/ranges/dirs in one call, a header each: show [-n] path[:A-B]...
show *specs:
    @cd "{{invocation_directory()}}" && "{{scripts}}/show.sh" "$@"

# `just preflight`, one line per step; on failure, that step's tail
preflight-brief:
    @"{{scripts}}/preflight-brief.sh"
