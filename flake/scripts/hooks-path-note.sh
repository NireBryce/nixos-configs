#!/usr/bin/env bash
# Preflight's first step: warn when git isn't pointed at .githooks/.
#
# core.hooksPath is per-clone config, so a fresh clone silently runs no
# pre-commit lint ratchet and no commit-msg trailer fixup; CI runs the same
# lint check either way, but the local hooks exist only after `just
# install-hooks`. This surfaces the missing state at the one moment an
# agent is already reading preflight output.
#
# Lives in flake/scripts/ rather than inline in the recipe because
# .justfile's header reserves conditionals and pipelines for scripts --
# the inline version it replaced was exactly that shape. Deliberately
# echo-only and never fails: CI has no hooksPath and preflight must stay
# green there. preflight-brief.sh prints NOTE lines from a step's output,
# so this reaches the ship skill's step-0 tool too.
set -euo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
# Wired means core.hooksPath resolves to an existing directory that is
# this checkout's .githooks or the main checkout's (a relative value resolves
# against the worktree top), so `.githooks` and an absolute path to the same
# directory both count.
hp=$(git -C "$root" config core.hooksPath || true)
case "$hp" in
    '') got= ;;
    /*) got=$(realpath -q "$hp" || true) ;;
    *) got=$(realpath -q "$root/$hp" || true) ;;
esac
# The main checkout is `git worktree list`'s first entry, whatever the
# git-dir layout (separate git dir, submodule).
main_wt=$(git -C "$root" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
here=$(realpath -q "$root/.githooks" || true)
main=$(realpath -q "${main_wt:-$root}/.githooks" || true)
if [ -z "$got" ] || [ ! -d "$got" ] \
    || { [ "$got" != "$here" ] && [ "$got" != "$main" ]; }; then
    echo "NOTE: git hooks not wired (core.hooksPath) -- 'just install-hooks' enables the pre-commit lint ratchet and the commit-msg trailer fixup; CI runs the same lint check either way"
fi
