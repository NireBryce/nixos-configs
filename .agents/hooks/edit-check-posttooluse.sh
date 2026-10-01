#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit matcher). Moves three checks that
# otherwise surface minutes later, at preflight or the next eval, to the
# moment the file is written. Context only (additionalContext), never a
# block: the edit has already happened, and each finding is a to-do for the
# agent's next step, not a reason to undo it.
#
#   wiki/*.md  -> `check_wiki.py siblings`, filtered to this page's pair.
#                 The whole check is ~0.1s, so no per-page flag was added;
#                 the filter is by path, and REVIEW (word-budget) lines
#                 are dropped as edit-time noise. A source edit whose
#                 sibling hasn't followed yet shows as STALE SIBLING --
#                 expected mid-edit, the reminder is the point (AGENTS.md
#                 "Docs", skill wiki-sync step 5).
#   *.nix      -> nix_shell_interp.py beside this script: shell-shaped
#                 `${...}` inside a `''` string (AGENTS.md trap). Flags only
#                 shapes that can't be working Nix (`${x[1]}`, `${x:-y}`,
#                 `${#x}`...); a bare `${VAR}` is a scope question only eval
#                 answers. `''${` escapes are lexed, not regexed.
#   untracked .nix under flake/modules/ -> the "git add before nix eval"
#                 reminder, at creation rather than at the eval that misses
#                 it (nix-untracked-guard-pretooluse.sh is the eval-time one).
#
# Never fails: no `set -e`; a missing python3 or check script skips that
# check. Missing jq is reported in a systemMessage (built without jq), like
# every hook in this directory.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

if ! command -v jq >/dev/null 2>&1; then
    cat >/dev/null
    printf '%s\n' '{"systemMessage":"edit-check-posttooluse: jq not on PATH, so this edit was NOT checked (wiki siblings, Nix string interpolation, untracked module). Install jq (packages-config/nix-utils/) to re-arm the hook."}'
    exit 0
fi

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null || true)
[ -n "$file" ] && [ -f "$file" ] || exit 0

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null) || exit 0
case "$file" in
    "$root"/*) rel=${file#"$root"/} ;;
    *) exit 0 ;;
esac
have_py=$(command -v python3 || true)

notes=()

case "$rel" in
    wiki/*.md)
        if [ -n "$have_py" ] && [ -f "$root/wiki/scripts/check_wiki.py" ]; then
            base=${rel%.md}; base=${base%-for-agents}
            hits=$(python3 "$root/wiki/scripts/check_wiki.py" siblings "$root" 2>/dev/null \
                | grep -F -e "$base.md" -e "$base-for-agents.md" \
                | grep -v '^REVIEW' || true)
            if [ -n "$hits" ]; then
                notes+=("check_wiki.py siblings, for this page's pair (fix in the same change; skill wiki-sync step 5):"$'\n'"$hits")
            fi
        fi
        ;;
esac

case "$rel" in
    *.nix)
        if [ -n "$have_py" ]; then
            hits=$(cd "$root" && python3 "$here/nix_shell_interp.py" "$rel" 2>/dev/null || true)
            [ -n "$hits" ] && notes+=("$hits")
        fi
        case "$rel" in
            flake/modules/*)
                if ! git -C "$root" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
                    notes+=("$rel is untracked: flakes ignore untracked files, so this module does not exist for nix eval / just check until you 'git add $rel' (AGENTS.md, \"git add before nix eval\").")
                fi
                ;;
        esac
        ;;
esac

[ "${#notes[@]}" -gt 0 ] || exit 0
ctx="edit-check (.agents/hooks/edit-check-posttooluse.sh):"
for n in "${notes[@]}"; do ctx+=$'\n'"- $n"; done
jq -n --arg ctx "$ctx" '{
    hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: $ctx }
}'
exit 0
