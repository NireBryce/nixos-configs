#!/usr/bin/env bash
# SessionStart hook. Hands the agent the repo state AGENTS.md otherwise asks
# it to remember to check -- "check `hostname`", "check `git branch
# --show-current`", "glance at `git worktree list` at session start"
# (skill use-a-worktree) -- as additionalContext, so it is in context before
# the first tool call instead of depending on the model reading that far.
#
# Also wires .githooks/ when it isn't: `git config core.hooksPath .githooks`
# is exactly what `just install-hooks` runs, repo-local, idempotent, and
# nothing else points hooksPath anywhere in this repo. Without it the
# commit-msg trailer fixup and the pre-commit lint ratchet silently don't run
# (flake/scripts/hooks-path-note.sh is preflight's warn-only version). The
# config lives in the common .git/config, so one set covers every worktree.
#
# Deliberately cheap and never failing: no `set -e`, every git call guarded,
# exit 0 always. Well under a second on this repo. `just branches`' stale
# count is NOT here: it takes ~7s and may call `gh` (network) per branch.
#
# Output: JSON hookSpecificOutput.additionalContext when jq exists; without
# jq, the same text as plain stdout, which SessionStart also adds to context
# (hooks docs, "exit code 0"), plus a line saying jq is missing -- the other
# hooks in this directory are unarmed without it.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

input=$(cat 2>/dev/null || true)
cwd=""
if command -v jq >/dev/null 2>&1; then
    cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null || true)
fi
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

lines=()
lines+=("hostname: $(hostname 2>/dev/null || uname -n 2>/dev/null)")

if root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
    branch=$(git -C "$root" branch --show-current 2>/dev/null || true)
    [ -n "$branch" ] || branch="(detached at $(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo '?'))"
    lines+=("branch: $branch")

    gitdir=$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null || true)
    common=$(cd "$root" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P || true)
    if [ -n "$gitdir" ] && [ -n "$common" ] && [ "$(cd "$gitdir" && pwd -P)" != "$common" ]; then
        lines+=("worktree: $root is a LINKED worktree (main checkout's .git: $common)")
    else
        lines+=("worktree: $root is the main checkout -- shared with other sessions; branch/commit work goes in a worktree (skill use-a-worktree)")
    fi

    dirty=$(git -C "$root" --no-optional-locks status --porcelain 2>/dev/null | grep -c . || true)
    lines+=("dirty paths (git status --porcelain): ${dirty:-?}")

    lines+=("git worktree list:")
    while IFS= read -r wt; do
        lines+=("  $wt")
    done < <(git -C "$root" worktree list 2>/dev/null || true)

    hooks_path=$(git -C "$root" config core.hooksPath 2>/dev/null || true)
    if [ "$hooks_path" = ".githooks" ]; then
        lines+=("core.hooksPath: .githooks (commit-msg trailer fixup and pre-commit lint ratchet active)")
    elif [ -d "$root/.githooks" ] && git -C "$root" config core.hooksPath .githooks 2>/dev/null; then
        lines+=("core.hooksPath: was '${hooks_path:-unset}', set it to .githooks just now (what 'just install-hooks' does)")
    else
        lines+=("core.hooksPath: '${hooks_path:-unset}', not .githooks, and setting it failed -- run 'just install-hooks'")
    fi
else
    lines+=("git: $cwd is not inside a git repo")
fi

text="Session start state (from .agents/hooks/session-start.sh; re-check before acting if time has passed):"
for l in "${lines[@]}"; do text+=$'\n'"$l"; done

if command -v jq >/dev/null 2>&1; then
    jq -n --arg ctx "$text" '{
        hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $ctx }
    }' 2>/dev/null && exit 0
fi
printf '%s\n%s\n' "$text" "jq not on PATH: the guard hooks in .agents/hooks/ cannot read their input and are unarmed until it is installed."
exit 0
