#!/usr/bin/env bash
# Is every commit of a multi-commit change green on its own (skill ship
# step 0, lessons-learned §15) -- `preflight-brief` on each, one line per
# commit. Replaces the throwaway-worktree loop ship spelled out by hand:
# `worktree add --detach /tmp/wt <sha> && cd ... && check; worktree
# remove`, re-typed per commit and left behind when a check failed.
#
#   preflight-each.sh [<range>]     default origin/experimental..HEAD
#
# Oldest first, in ONE throwaway detached worktree (checked out per
# commit), so nothing touches a branch pointer or the caller's tree.
# Output, flushed as each commit finishes so a background runner can
# follow it:
#   ok   <sha> <subject>  (<n> steps, <s>s)
#   FAIL <sha> <subject>  then preflight-brief's own output, indented
# Every commit runs even after a failure; exit 1 if any failed, 2 on
# usage. The worktree is removed on any exit, Ctrl-C and SIGTERM
# included (trap). `git fetch origin` first, so the default range is
# against the trunk as it is now.
#
# PREFLIGHT_EACH_CMD overrides the per-commit command (default: this
# directory's preflight-brief.sh, run inside the throwaway worktree, where
# it reads that commit's own preflight recipe). Tests use it; it is eval'd.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cmd=${PREFLIGHT_EACH_CMD:-"$here/preflight-brief.sh"}
range=${1:-origin/experimental..HEAD}
[[ $# -le 1 ]] || { echo "usage: preflight-each.sh [<range>]" >&2; exit 2; }

cd "$(git rev-parse --show-toplevel)" || exit 2
git fetch -q origin 2>/dev/null || echo "warning: git fetch origin failed; using local refs" >&2

mapfile -t shas < <(git rev-list --reverse "$range" 2>/dev/null)
if [[ ${#shas[@]} -eq 0 ]]; then
    git rev-parse -q --verify "${range##*..}^{commit}" >/dev/null 2>&1 \
        || { echo "bad range: $range" >&2; exit 2; }
    echo "no commits in $range"
    exit 0
fi

wt=$(mktemp -d "${TMPDIR:-/tmp}/preflight-each.XXXXXX") || exit 2
log=$(mktemp) || exit 2
cleanup() {
    git worktree remove --force "$wt" >/dev/null 2>&1
    rm -rf "$wt" "$log"
    git worktree prune >/dev/null 2>&1
}
trap cleanup EXIT
# The check runs as a background job in its own process group (set -m),
# so a signal interrupts `wait` at once and the trap can stop the whole
# check (just, nix, ...) rather than waiting for it to finish.
child=
trap 'echo "interrupted" >&2; [[ -n $child ]] && kill -- -"$child" 2>/dev/null; exit 130' INT TERM
set -m

git worktree add -q --detach "$wt" "${shas[0]}" || exit 2
echo "preflight-each: ${#shas[@]} commits in $range (worktree $wt)"

failed=0
for sha in "${shas[@]}"; do
    short=${sha:0:8}
    subject=$(git log -1 --format=%s "$sha")
    start=$SECONDS
    git -C "$wt" checkout -q --detach --force "$sha" && git -C "$wt" clean -qfdx
    (cd "$wt" && eval "$cmd") >"$log" 2>&1 &
    child=$!
    wait "$child"
    rc=$? child=
    if [[ $rc -eq 0 ]]; then
        steps=$(sed -n 's/^preflight passed: \([0-9]*\) steps$/\1/p' "$log" | tail -1)
        printf 'ok   %s %s  (%s steps, %ss)\n' "$short" "$subject" "${steps:-?}" $((SECONDS - start))
    else
        failed=1
        printf 'FAIL %s %s  (%ss)\n' "$short" "$subject" $((SECONDS - start))
        tail -n 40 "$log" | sed 's/^/     /'
    fi
done
exit $failed
