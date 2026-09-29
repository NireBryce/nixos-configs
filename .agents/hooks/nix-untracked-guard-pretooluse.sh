#!/usr/bin/env bash
# PreToolUse hook (Bash matcher). Warns when a flake-evaluating command runs
# while untracked .nix files exist: flakes in a git repo ignore untracked
# files entirely, so a module written minutes ago silently does not exist
# from the evaluation's point of view -- AGENTS.md, "git add before nix
# eval". `just modules` catches this at preflight time; this catches it at
# the moment of the mistake instead, before the wrong result gets read.
#
# Warn-only systemMessage, never an ask: untracked .nix files are often
# deliberate (a scratch experiment, a not-yet-wanted module), and the worst
# case without the warning is one evaluation trusted too far -- no damage
# to undo. systemMessage rather than permissionDecision, so the warning is
# not a silent no-op under an auto permission mode (git-guard's header has
# the full mechanism).
#
# Known limits: the match is a string pattern, so `echo nix eval` warns and
# a flake-ref form like `nix run nixpkgs#hello` warns though it never reads
# this repo -- over-warning is the safe direction here. `nix fmt` and
# `nix shell` are left out: they do not evaluate this repo's flake.
# `nix develop` IS watched -- it evaluates this flake's devShells, lower
# stakes than a system eval but the same invisibility. A command that
# evaluates through a script (rebuild.sh under `just build`) is caught via
# the `just <recipe>` shapes below, not by parsing the script. `just
# modules` is deliberately excluded: modules.py runs its own untracked
# check and would double-warn.
set -euo pipefail

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")

if ! grep -qE '\bnix[[:space:]]+(eval|build|run|develop|profile|flake)\b|\bnh[[:space:]]+(os|home|d)\b|\bjust[[:space:]]+(build|boot|switch|check|update|diff|fingerprint|fingerprint-home)\b' <<<"$command"; then
    exit 0
fi

# Evaluate against the repo the command would run in -- the tool's cwd, not
# the project dir, so this stays correct inside a git worktree (where the
# same untracked rule applies to the worktree's own files).
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-.}"
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0

untracked=$(git -C "$root" ls-files --others --exclude-standard -- '*.nix')
if [ -n "$untracked" ]; then
    count=$(wc -l <<<"$untracked")
    jq -n --arg count "$count" --arg first "$(head -n 1 <<<"$untracked")" \
        '{ systemMessage: ("⚠️  UNTRACKED .nix FILES (" + $count + ", e.g. " + $first + "): flakes ignore untracked files, so anything not git-added is invisible to this evaluation -- git add before trusting its result (AGENTS.md, \"git add before nix eval\").") }'
fi
exit 0
