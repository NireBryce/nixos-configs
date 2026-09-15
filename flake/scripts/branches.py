#!/usr/bin/env python3
"""Local branch hygiene: which branches are done, and which still hold work.

The `ship` skill deletes a branch right after it merges, so in principle none
of this should accumulate. In practice it does anyway, because there are three
ways a branch outlives its work and none of them go through that flow:

  - the PR is merged from GitHub's web UI, or by another session, and the local
    branch is simply never deleted;
  - the PR is CLOSED rather than merged, so the branch holds a real, rejected
    or parked commit that nobody wants silently dropped;
  - the branch never had a PR at all.

2026-09-11: 15 local branches, 11 of them fully merged and deletable, and the
buildup had made the other 4 invisible. That is the failure this exists to
prevent -- not the clutter, but a genuinely unmerged branch hiding in it.

WHY PATCH-ID, NOT `git branch --merged`. This repo rebases on merge (`gh pr
merge --rebase`), so a merged branch's commits get NEW SHAs upstream and the
old branch is not an ancestor of anything. `--merged` calls all 11 of those
unmerged, which is precisely backwards and why they were never cleaned up. A
patch-id is a hash of a commit's DIFF, ignoring SHA, parents, author and
message, so a rebased commit keeps it. If every commit on a branch has its
patch-id somewhere in the trunk's recent history, the branch's work is landed
regardless of what the SHAs say.

Patch-id covers the rebased shape of landing; the forge's PR RECORD covers
the merged shape (#334). A PR merged with `--merge` (the ship skill's
default for multi-commit PRs) preserves the branch's SHAs as merge parents,
so the branch is an ancestor of the trunk and `log TRUNK..b` comes back
empty -- nothing for patch-id to match. Until 2026-09-14 that read NEW, so
prune never offered merge-landed branches and landed work accumulated
looking like live work. They are MERGED when `gh` records their PR MERGED
-- the record that landed the branch is the evidence it landed. Ancestry
alone was considered and rejected while fixing this: it cannot tell a
merge-landed branch from a fresh one whose base the trunk has since
advanced past, which is #300's window exactly. One gh call is spent per
empty-log branch (rare); offline or on gh failure the verdict degrades to
NEW -- asks rather than deletes.

Limits worth knowing before trusting a MERGED verdict: patch-id is computed
over the diff, so a commit that landed upstream in a SQUASHED or reworked form
will not match and is reported UNMERGED (safe direction -- it asks rather than
deletes). Merge commits produce no patch-id at all, so they are excluded from
the verdict rather than counted either way: a branch of nothing but merges is
UNMERGED, since there is nothing readable to verify. And only the trunk's
most recent --depth commits are indexed, so a branch merged long ago can fall
off the back; raise --depth if a known-merged branch reports UNMERGED.

    branches.py check              # classify every local branch
    branches.py prune              # delete the MERGED ones (asks first)
    branches.py prune --yes        # ... without asking

`prune` with no `--yes` needs a terminal to ask in. Run without one (an agent
session, a hook, CI) it says so and exits 2 rather than dying on `input()`'s
EOFError, which is what it did until 2026-09-14.

Never deletes an UNMERGED branch, a NEW one (nothing ahead of the trunk
that the forge doesn't record as a merged PR -- almost always a branch
someone just created), a branch checked out in any worktree, `main`, the
trunk, or the current branch -- not even with --yes.
Those need a human looking at them.

Only an exact MERGED verdict is deletable, which is why every other state
carries a suffix rather than its own arm: `MERGED (worktree)` is not
`MERGED`.

The classifier has a fixture test, `flake/scripts/test_branches.py` (`just
branches-test`, part of `just preflight` and CI): every verdict state built
in a throwaway repo, asserting the verdicts and exactly what prune deletes.
It exists because #300 shipped two misclassifications -- a no-commits branch
reading MERGED, an all-merges branch reading MERGED -- either of which would
have force-deleted a real branch, and nothing would have caught either; #334
a third, a merge-landed branch reading NEW so landed work accumulated
invisibly (the failure mode this script exists to prevent, in the safe
direction). Change classify() only with that test green; it is the safety
net this script otherwise lacks.
"""
import argparse, subprocess, sys

TRUNK = 'experimental'
PROTECTED = {TRUNK, 'main'}


def git(*args, check=True):
    r = subprocess.run(['git', *args], capture_output=True, text=True)
    if check and r.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{r.stderr.strip()}")
    return r.stdout.strip()


def patch_id(commit):
    """The diff's identity, stable across rebase. Empty for a merge commit."""
    show = subprocess.run(['git', 'show', commit], capture_output=True, text=True)
    pid = subprocess.run(['git', 'patch-id', '--stable'],
                         input=show.stdout, capture_output=True, text=True)
    out = pid.stdout.split()
    return out[0] if out else None


def trunk_patch_ids(depth):
    ids = set()
    for c in git('log', '--format=%H', f'-{depth}', TRUNK).splitlines():
        p = patch_id(c)
        if p:
            ids.add(p)
    return ids


def worktree_branches():
    """{branch: worktree path} for every branch checked out in ANY worktree of
    this repo, not just the one we were invoked from.

    Added 2026-09-12. `b == current` below only ever saw the invoking
    checkout's HEAD, so a branch another session had checked out in its own
    worktree was classified as though nobody held it -- and the summary line
    counted it under "still holding work or checked out" while reporting
    zero of them. git itself refuses `branch -D` on such a branch ("cannot
    delete branch 'x' used by worktree at ..."), which is what actually kept
    prune honest here; this makes the script stop proposing what git would
    then refuse."""
    held, path = {}, None
    for line in git('worktree', 'list', '--porcelain').splitlines():
        if line.startswith('worktree '):
            path = line[len('worktree '):]
        elif line.startswith('branch '):
            held[line[len('branch refs/heads/'):]] = path
    return held


def classify(depth):
    """-> list of (branch, verdict, landed, total, unlanded_subjects)."""
    trunk_ids = trunk_patch_ids(depth)
    trunk_tip = git('rev-parse', TRUNK)
    current = git('rev-parse', '--abbrev-ref', 'HEAD')
    held = worktree_branches()
    rows = []
    for b in git('for-each-ref', '--format=%(refname:short)', 'refs/heads/').splitlines():
        if b in PROTECTED:
            continue
        commits = git('log', '--format=%H', f'{TRUNK}..{b}').splitlines()
        landed, unlanded, opaque = 0, [], 0
        for c in commits:
            p = patch_id(c)
            if p is None:
                # `git patch-id` emits nothing for a merge commit, so we
                # cannot tell whether its content is in the trunk. Until
                # 2026-09-12 that counted as LANDED, which is the unsafe
                # direction and contradicted this script's own docstring
                # listing merges among the limits that "report UNMERGED".
                # A branch whose only commits were merges was therefore
                # MERGED and deletable -- and a merge commit can carry real
                # conflict resolutions that exist nowhere else.
                opaque += 1
            elif p in trunk_ids:
                landed += 1
            else:
                unlanded.append(git('log', '-1', '--format=%s', c))
        classifiable = len(commits) - opaque
        if not commits:
            # An empty `log TRUNK..b` proves the head is an ancestor of the
            # trunk -- and that is ALL it proves. Two states hide in it: a
            # branch just created and holding nothing, and a branch fully
            # landed by a MERGE commit (#334 -- the ship skill's default for
            # multi-commit PRs preserves the branch's SHAs, so there is
            # nothing for patch-id to match). Until 2026-09-14 this whole
            # arm read NEW, so merge-landed branches accumulated looking
            # like live work. Until 2026-09-12 it read MERGED, which is
            # #300: a fresh branch was offered to `branch -D` in exactly
            # the window between another session branching and its first
            # commit, observed live on `landing-homepage`.
            #
            # Pure git cannot tell the two apart. The obvious tip check goes
            # STALE the moment the trunk advances past a fresh branch's base
            # -- that is #300's window again, a routine occurrence with
            # concurrent sessions -- so ancestry alone was rejected when
            # this was fixed: it re-opens #300 to fix #334. The forge's PR
            # record is the discriminator: `--merge` landing happens through
            # a PR, so the record that landed the branch is the evidence it
            # landed. MERGED only on that record; no PR, OPEN, CLOSED, or
            # gh unavailable all read NEW -- the safe direction.
            if git('rev-parse', b) == trunk_tip:
                verdict = 'NEW'
            elif pr_merged(b):
                verdict = 'MERGED'
            else:
                verdict = 'NEW'
        elif classifiable and landed == classifiable:
            # Every commit we can actually read is in the trunk. Merge
            # commits alongside them are noise once the real work landed.
            verdict = 'MERGED'
        else:
            # Includes the all-merges case (classifiable == 0): nothing to
            # verify, so it is not deletable.
            verdict = 'UNMERGED'
        if b == current:
            verdict += ' (current)'
        elif b in held:
            verdict += ' (worktree)'
        rows.append((b, verdict, landed, len(commits), unlanded))
    return rows


def pr_state(branch):
    r = subprocess.run(
        ['gh', 'pr', 'list', '--head', branch, '--state', 'all',
         '--json', 'number,state',
         '--jq', '.[0] // empty | "#\\(.number) \\(.state)"'],
        capture_output=True, text=True)
    out = r.stdout.strip()
    # `.[0] // empty` on an empty list prints nothing; without the `// empty`
    # jq renders the null as the literal "#null null", which reads like a
    # real PR number at a glance.
    return '' if out in ('', 'null', '#null null') else out


def pr_merged(branch):
    """True when the branch's most recent PR is recorded MERGED. Empty or a
    gh failure reads False: the ambiguous arm classifies NEW, the safe
    direction (asks rather than deletes)."""
    return pr_state(branch).endswith('MERGED')


def cmd_check(args):
    rows = classify(args.depth)
    if not rows:
        print('no local branches besides ' + ', '.join(sorted(PROTECTED)))
        return 0
    for b, verdict, landed, total, unlanded in sorted(rows):
        pr = pr_state(b) if args.pr else ''
        if landed == total == 0:
            # A no-commits branch: `(0/0 landed)` is what both the #300 and
            # #334 confusion printed, and it explains neither verdict. Say
            # what each one actually means.
            detail = ('landed by merge commit'
                      if verdict.startswith('MERGED')
                      else 'nothing ahead of trunk yet')
            print(f'{verdict:<18} {b:<34} ({detail}) {pr}')
        else:
            print(f'{verdict:<18} {b:<34} ({landed}/{total} landed) {pr}')
        for s in unlanded:
            print(f'{"":<18}   unlanded: {s[:66]}')
    n = sum(1 for r in rows if r[1] == 'MERGED')
    print(f'\n{n} deletable, {len(rows) - n} still holding work, newly '
          f'created, or checked out.')
    if n:
        print('`just branches prune` deletes the MERGED ones '
              '(add --yes when nothing can answer a prompt).')
    return 0


def cmd_prune(args):
    # Exact match only: 'MERGED (current)' and 'MERGED (worktree)' must not
    # pass, and neither must 'NEW'. See classify().
    rows = [r for r in classify(args.depth) if r[1] == 'MERGED']
    if not rows:
        print('nothing to prune')
        return 0
    for b, _, landed, total, _ in sorted(rows):
        if landed == total == 0:
            # #334's merge-landed case: no commits ahead to count -- say
            # how it landed, not a ratio that explains nothing.
            print(f'  {b}  (landed by merge commit)')
        else:
            print(f'  {b}  ({landed}/{total} commits already in {TRUNK})')
    if not args.yes:
        # Non-interactive callers (agent sessions, hooks, CI) get a usable
        # message instead of EOFError's traceback -- the prompt below has no
        # stdin to read and the verdict above is the part worth keeping.
        if not sys.stdin.isatty():
            print(f'\nnot a terminal, so nothing was deleted: re-run as '
                  f'`just branches prune --yes` to delete these {len(rows)}.',
                  file=sys.stderr)
            return 2
        if input(f'\nDelete these {len(rows)} local branches? [y/N] ').lower() != 'y':
            sys.exit('aborted')
    for b, *_ in rows:
        # -D, not -d: these are verified landed -- by patch-id, or (#334)
        # by the forge's PR record -- and -d refuses a rebased branch
        # precisely because its SHAs differ. The verification above is what
        # makes that safe; do not weaken it.
        print(git('branch', '-D', b))
    print(f'\n{len(rows)} deleted. `git remote prune origin` clears stale '
          'remote-tracking refs separately.')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('command', choices=['check', 'prune'], nargs='?', default='check')
    ap.add_argument('--depth', type=int, default=400,
                    help='how many trunk commits to index patch-ids for (default 400)')
    ap.add_argument('--yes', action='store_true', help='prune without confirming')
    ap.add_argument('--no-pr', dest='pr', action='store_false',
                    help="skip the `gh pr` lookup per branch")
    args = ap.parse_args()
    return cmd_check(args) if args.command == 'check' else cmd_prune(args)


if __name__ == '__main__':
    sys.exit(main())
