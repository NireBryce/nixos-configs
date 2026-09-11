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

Limits worth knowing before trusting a MERGED verdict: patch-id is computed
over the diff, so a commit that landed upstream in a SQUASHED or reworked form
will not match and is reported UNMERGED (safe direction -- it asks rather than
deletes). Merge commits are skipped by `git patch-id`. And only the trunk's
most recent --depth commits are indexed, so a branch merged long ago can fall
off the back; raise --depth if a known-merged branch reports UNMERGED.

    branches.py check              # classify every local branch
    branches.py prune              # delete the MERGED ones (asks first)
    branches.py prune --yes        # ... without asking

Never deletes an UNMERGED branch, `main`, the trunk, or the current branch --
not even with --yes. Those need a human looking at them.
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


def classify(depth):
    """-> list of (branch, verdict, landed, total, unlanded_subjects)."""
    trunk_ids = trunk_patch_ids(depth)
    current = git('rev-parse', '--abbrev-ref', 'HEAD')
    rows = []
    for b in git('for-each-ref', '--format=%(refname:short)', 'refs/heads/').splitlines():
        if b in PROTECTED:
            continue
        commits = git('log', '--format=%H', f'{TRUNK}..{b}').splitlines()
        landed, unlanded = 0, []
        for c in commits:
            p = patch_id(c)
            if p is None or p in trunk_ids:
                landed += 1
            else:
                unlanded.append(git('log', '-1', '--format=%s', c))
        verdict = 'MERGED' if commits and landed == len(commits) else (
            'MERGED' if not commits else 'UNMERGED')
        if b == current:
            verdict += ' (current)'
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


def cmd_check(args):
    rows = classify(args.depth)
    if not rows:
        print('no local branches besides ' + ', '.join(sorted(PROTECTED)))
        return 0
    for b, verdict, landed, total, unlanded in sorted(rows):
        pr = pr_state(b) if args.pr else ''
        print(f'{verdict:<18} {b:<34} ({landed}/{total} landed) {pr}')
        for s in unlanded:
            print(f'{"":<18}   unlanded: {s[:66]}')
    n = sum(1 for r in rows if r[1] == 'MERGED')
    print(f'\n{n} deletable, {len(rows) - n} still holding work or checked out.')
    if n:
        print('`just branches prune` deletes the MERGED ones.')
    return 0


def cmd_prune(args):
    rows = [r for r in classify(args.depth) if r[1] == 'MERGED']
    if not rows:
        print('nothing to prune')
        return 0
    for b, _, landed, total, _ in sorted(rows):
        print(f'  {b}  ({landed}/{total} commits already in {TRUNK})')
    if not args.yes:
        if input(f'\nDelete these {len(rows)} local branches? [y/N] ').lower() != 'y':
            sys.exit('aborted')
    for b, *_ in rows:
        # -D, not -d: these are verified landed by patch-id, and -d refuses a
        # rebased branch precisely because its SHAs differ. The verification
        # above is what makes that safe; do not weaken it.
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
