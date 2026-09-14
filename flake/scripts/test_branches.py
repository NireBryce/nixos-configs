#!/usr/bin/env python3
"""Fixture tests for branches.py's classifier -- the safety net issue #303 asked for.

`just branches prune` force-deletes (`branch -D`) every branch classify()
calls exactly MERGED, so a misclassification deletes someone's branch. Two
such misclassifications shipped and were fixed by hand in #300, both found
by accident while doing something else: a branch with no commits ahead of
the trunk read MERGED (the window between another session creating a branch
and its first commit -- it survived only because git refuses to delete a
branch checked out in a worktree), and a branch whose only commit ahead was
a merge of the trunk read MERGED because `git patch-id` emits nothing for a
merge commit, though a merge can carry conflict resolutions that exist
nowhere else. Nothing would have caught either; that is the gap this file
closes.

The classifier reads local git state -- what branches exist here, what
worktrees are open, where the local trunk points -- which is exactly what
differs between clones and is absent in CI, so the command itself is
untestable as a gate (the issue's own "why it isn't simply added to
preflight"). What is testable is classify() against a constructed repo: the
test builds a throwaway one in a temp directory (trunk branch named
`experimental`, which branches.py hardcodes as TRUNK), constructs every
verdict state as a fixture branch, and asserts both the verdicts and, end to
end, exactly which branches `prune --yes` deletes. Same-diff-different-SHA
landing is simulated by committing identical file content in two places --
identical diffs are identical patch-ids, which is what a rebased merge looks
like to the classifier minus the rebase. Pure stdlib plus git; no fleet
state, no network, no `gh` (only `check` talks to gh, and the test drives
classify()/prune directly). Runs via `just branches-test`, part of `just
preflight` and CI.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from argparse import Namespace

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import branches


class ClassifierTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.mkdtemp(prefix='branches-test-')
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        self.repo = os.path.join(tmp, 'repo')
        self.worktrees = os.path.join(tmp, 'worktrees')
        os.mkdir(self.repo)
        os.mkdir(self.worktrees)
        self.addCleanup(os.chdir, os.getcwd())
        os.chdir(self.repo)

        self.git('init', '-q', '-b', 'experimental')
        # commit.gpgsign=false because a global sign-everything setting would
        # fail these commits with no key configured; hooksPath=/dev/null so a
        # global core.hooksPath cannot run repo-specific hooks against a
        # throwaway tree (the --no-verify below only covers the commits
        # themselves, not the merges).
        self.git('config', 'commit.gpgsign', 'false')
        self.git('config', 'core.hooksPath', os.devnull)
        self.git('config', 'user.name', 'branches-test')
        self.git('config', 'user.email', 'branches-test@example.com')
        self.commit_file('trunk.txt', 'base\n', 'trunk base')

        # NEW: exists, nothing ahead of the trunk yet -- #300's
        # created-but-not-yet-committed window. Must never read MERGED.
        self.git('branch', 'fresh')

        # UNMERGED: one ordinary commit the trunk does not contain.
        self.git('checkout', '-q', '-b', 'unlanded', 'experimental')
        self.commit_file('unlanded.txt', 'work\n', 'unlanded work')

        # MERGED, rebase shape: branch commit and trunk commit carry
        # identical content, so identical diffs under different SHAs.
        self.git('checkout', '-q', '-b', 'rebased-landed', 'experimental')
        self.commit_file('feature-a.txt', 'landed a\n', 'landed work a')
        self.git('checkout', '-q', 'experimental')
        self.commit_file('feature-a.txt', 'landed a\n', 'trunk side of a')

        # UNMERGED, second #300 bug: the only commit ahead is a merge of the
        # trunk, and a merge commit has no patch-id, so there is nothing
        # verifiable -- potentially carrying conflict resolutions that exist
        # nowhere else.
        self.git('checkout', '-q', '-b', 'merge-only', 'experimental')
        self.git('checkout', '-q', 'experimental')
        self.commit_file('trunk.txt', 'base\nmove\n', 'trunk moves on')
        self.git('checkout', '-q', 'merge-only')
        self.git('merge', '--no-ff', '-q', '-m', 'catch up with trunk',
                 'experimental')

        # MERGED despite a merge commit alongside: the real work landed, and
        # a merge next to landed work is noise, not evidence against.
        self.git('checkout', '-q', '-b', 'merged-with-merge', 'experimental')
        self.commit_file('feature-b.txt', 'landed b\n', 'landed work b')
        self.git('checkout', '-q', 'experimental')
        self.commit_file('feature-b.txt', 'landed b\n', 'trunk side of b')
        self.commit_file('trunk.txt', 'base\nmove\nmore\n', 'trunk moves again')
        self.git('checkout', '-q', 'merged-with-merge')
        self.git('merge', '--no-ff', '-q', '-m', 'catch up again',
                 'experimental')

        # UNMERGED, mixed: one landed commit and one unlanded one -- partly
        # landed is not landed, and the unlanded half should be named.
        self.git('checkout', '-q', '-b', 'partial', 'experimental')
        self.commit_file('feature-c.txt', 'landed c\n', 'partial landed')
        self.commit_file('feature-d.txt', 'unlanded d\n', 'partial unlanded')
        self.git('checkout', '-q', 'experimental')
        self.commit_file('feature-c.txt', 'landed c\n', 'trunk side of c')

        # MERGED verdict but held by another worktree: the suffix must break
        # the exact-MERGED match prune deletes on. #300's live save was git
        # refusing `branch -D` on a held branch; the script must not even
        # propose what git would refuse.
        self.git('checkout', '-q', '-b', 'held-merged', 'experimental')
        self.commit_file('feature-e.txt', 'landed e\n', 'landed work e')
        self.git('checkout', '-q', 'experimental')
        self.commit_file('feature-e.txt', 'landed e\n', 'trunk side of e')
        self.git('worktree', 'add', '-q',
                 os.path.join(self.worktrees, 'held'), 'held-merged')

        # MERGED verdict but the current branch of the invoking checkout --
        # the other suffix prune must not match past.
        self.git('checkout', '-q', '-b', 'current-landed', 'experimental')
        self.commit_file('feature-f.txt', 'landed f\n', 'landed work f')
        self.git('checkout', '-q', 'experimental')
        self.commit_file('feature-f.txt', 'landed f\n', 'trunk side of f')
        self.git('checkout', '-q', 'current-landed')

    def git(self, *args):
        subprocess.run(['git', *args], cwd=self.repo, check=True,
                       capture_output=True, text=True)

    def commit_file(self, name, content, message):
        with open(os.path.join(self.repo, name), 'w') as f:
            f.write(content)
        self.git('add', name)
        self.git('commit', '--no-verify', '-q', '-m', message)

    def rows(self):
        return {b: (verdict, landed, total, unlanded)
                for b, verdict, landed, total, unlanded
                in branches.classify(400)}

    def test_classify_verdicts(self):
        rows = self.rows()
        self.assertEqual(rows['fresh'][0], 'NEW')
        self.assertEqual(rows['unlanded'][0], 'UNMERGED')
        self.assertEqual(rows['rebased-landed'][0], 'MERGED')
        self.assertEqual(rows['merge-only'][0], 'UNMERGED')
        self.assertEqual(rows['merged-with-merge'][0], 'MERGED')
        self.assertEqual(rows['partial'][0], 'UNMERGED')
        # The suffixes are load-bearing: prune deletes on an exact match
        # against 'MERGED', so 'MERGED (worktree)' must not equal it.
        self.assertEqual(rows['held-merged'][0], 'MERGED (worktree)')
        self.assertEqual(rows['current-landed'][0], 'MERGED (current)')
        # The trunk (and main, were it here) is never classified at all.
        self.assertNotIn('experimental', rows)

    def test_landed_counts(self):
        rows = self.rows()
        self.assertEqual(rows['rebased-landed'][1:3], (1, 1))
        self.assertEqual(rows['merge-only'][1:3], (0, 1))
        self.assertEqual(rows['merged-with-merge'][1:3], (1, 2))
        self.assertEqual(rows['partial'][1:3], (1, 2))

    def test_partial_names_the_unlanded_commit(self):
        self.assertEqual(self.rows()['partial'][3], ['partial unlanded'])

    def test_prune_deletes_exactly_the_merged_verdicts(self):
        self.assertEqual(
            branches.cmd_prune(Namespace(command='prune', depth=400,
                                         yes=True, pr=True)), 0)
        remaining = branches.git(
            'for-each-ref', '--format=%(refname:short)',
            'refs/heads/').splitlines()
        self.assertNotIn('rebased-landed', remaining)
        self.assertNotIn('merged-with-merge', remaining)
        # Everything else survives -- every non-MERGED state, both suffixed
        # MERGEDs, and the protected trunk.
        for survivor in ('fresh', 'unlanded', 'merge-only', 'partial',
                         'held-merged', 'current-landed', 'experimental'):
            self.assertIn(survivor, remaining)


if __name__ == '__main__':
    unittest.main()
