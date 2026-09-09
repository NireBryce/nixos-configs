#! /usr/bin/env bash
# Close the issues a merged PR claims to fix, when GitHub's closing
# keyword silently didn't.
#
#   close-fixed.sh <pr-number>
#
# The known failure (issue #177, confirmed 2026-09-06 on PRs #142/#143/#144):
# correct "Fixes #N" syntax, merged, and the referenced issue stayed open
# with no error anywhere. The link is formed from the PR *body* at creation
# time (confirmed 2026-09-09: a keyword in the commit message alone forms
# no link; the same keyword in the PR body does), but whether the merge
# actually fires the close is not to be trusted either -- so this checks
# each issue a merged PR claims, and closes by hand the ones still OPEN.
#
# Scope guard: the PR must be merged. Closing an issue because a PR merely
# *claims* its fix would close work that hasn't landed.
#
# Refuses nothing else quietly: every issue it closes gets a comment saying
# it was closed by hand and why, so the tracker shows the keyword broke
# rather than a clean automatic close nobody can distinguish from the real
# thing.
#
# See also: the ship skill's closing-keyword section (the manual form of
# this loop, and the instruction to run it after every keyword merge).
set -euo pipefail

if (($# != 1)); then
    echo "usage: close-fixed.sh <pr-number>" >&2
    exit 2
fi

repo=NireBryce/nixos-configs
pr=$1

if ! command -v gh > /dev/null; then
    echo "gh not on PATH" >&2
    exit 2
fi

state=$(gh pr view "$pr" --repo "$repo" --json state --jq .state)
if [[ "$state" != "MERGED" ]]; then
    echo "PR #$pr is $state, not MERGED -- refusing to close anything it claims (the fix has not landed)" >&2
    exit 1
fi

merge_commit=$(gh pr view "$pr" --repo "$repo" --json mergeCommit --jq '.mergeCommit.oid // empty')

# The linked set (what GitHub parsed from the body) plus whatever closing
# keywords the body carries -- the union, because the known failure is
# precisely that one of these can be empty while the other isn't.
issues=$(
    {
        gh pr view "$pr" --repo "$repo" --json closingIssuesReferences \
            --jq '.closingIssuesReferences[].number' || true
        gh pr view "$pr" --repo "$repo" --json body --jq .body \
            | grep -oiE '\b(fixes|fix|closes|close|resolves|resolve[d]?) #[0-9]+' \
            | grep -oE '[0-9]+$' || true
    } | sort -un
)

if [[ -z "$issues" ]]; then
    echo "PR #$pr: no closing keywords and no linked issues -- nothing to do"
    exit 0
fi

closed=0
for issue in $issues; do
    issue_state=$(gh issue view "$issue" --repo "$repo" --json state --jq .state)
    if [[ "$issue_state" == "CLOSED" ]]; then
        echo "issue #$issue: already closed"
        continue
    fi
    gh issue close "$issue" --repo "$repo" --comment \
        "Closed by hand: PR #$pr merged with a closing keyword for this issue, but GitHub's auto-close didn't fire (the known silent failure in #177). Fix landed in ${merge_commit:-$pr}." \
        > /dev/null
    echo "issue #$issue: OPEN -> closed by hand"
    closed=$((closed + 1))
done

total=$(printf '%s\n' "$issues" | wc -l)
echo "done: $closed of $total issue(s) needed a hand close"
