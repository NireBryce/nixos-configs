#!/usr/bin/env python3
"""Fixture tests for check_trailers.py, the CI gate on Claude
Co-Authored-By trailers.

Two halves. The line classifier against every trailer shape the log
actually holds (`git log --format=%B | grep -i '^co-authored-by'`,
2026-09-29: canonical, `Claude Sonnet 5 <email>`, `Claude <email>`,
`Claude Opus 5 <email>`, `ZCode`, `opencode`) plus the near-misses a
regex gets wrong. Then end to end against a throwaway repo shaped like a
PR: a base whose history already holds a wrong trailer (which must NOT
fail -- AGENTS.md keeps old trailers), and branch commits on top, checked
as `base..branch` the way CI checks `HEAD^1..HEAD^2`. Pure stdlib plus
git; runs via `just trailers-test`, part of `just preflight`.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import check_trailers  # noqa: E402

SCRIPT = os.path.join(HERE, "check_trailers.py")


class ClassifierTests(unittest.TestCase):
    def assertFlagged(self, line):
        self.assertEqual(check_trailers.bad_trailers(f"subject\n\n{line}\n"),
                         [line], line)

    def assertPasses(self, line):
        self.assertEqual(check_trailers.bad_trailers(f"subject\n\n{line}\n"),
                         [], line)

    def test_canonical_passes(self):
        self.assertPasses("Co-Authored-By: Claude")

    def test_model_and_email_flagged(self):
        self.assertFlagged(
            "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>")
        self.assertFlagged(
            "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>")

    def test_email_only_flagged(self):
        self.assertFlagged("Co-Authored-By: Claude <noreply@anthropic.com>")
        self.assertFlagged("Co-Authored-By: Claude<noreply@anthropic.com>")

    def test_model_only_flagged(self):
        self.assertFlagged("Co-Authored-By: Claude Opus 5")
        self.assertFlagged("Co-Authored-By: Claude Code")

    def test_key_case_and_spacing_flagged(self):
        # Git reads trailer keys case-insensitively; the canonical form
        # is still the one spelling.
        self.assertFlagged("Co-authored-by: Claude Sonnet 5")
        self.assertFlagged("co-authored-by: Claude")
        self.assertFlagged("Co-Authored-By:  Claude")

    def test_other_agents_pass(self):
        for line in ("Co-Authored-By: ZCode", "Co-Authored-By: opencode",
                     "Co-Authored-By: Nire Bryce <nire@example.com>"):
            self.assertPasses(line)

    def test_claude_prefix_of_another_name_passes(self):
        # `Claude` must be a whole word: another agent whose name merely
        # starts with it is not this convention's business.
        self.assertPasses("Co-Authored-By: ClaudeBot")

    def test_prose_mention_passes(self):
        # Only a trailer-shaped line counts, not the string in a body.
        self.assertPasses("The hook rewrites Co-Authored-By: Claude Opus 5 "
                          "lines.")
        self.assertPasses("  Co-Authored-By: Claude Opus 5")


class RangeTests(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.mkdtemp(prefix="trailers-test-")
        self.addCleanup(shutil.rmtree, self.repo, ignore_errors=True)
        self.git("init", "-q", "-b", "experimental")
        # Same isolation as test_branches.py: no signing, no global hooks
        # (a real commit-msg hook would "fix" the fixtures).
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", os.devnull)
        self.git("config", "user.name", "trailers-test")
        self.git("config", "user.email", "trailers-test@example.com")
        self.commit("old\n\nCo-Authored-By: Claude Sonnet 5 "
                    "<noreply@anthropic.com>")
        self.git("branch", "base")
        self.git("checkout", "-q", "-b", "pr")

    def git(self, *args):
        return subprocess.run(["git", "-C", self.repo, *args], check=True,
                              capture_output=True, text=True).stdout

    def commit(self, message):
        self.git("commit", "-q", "--allow-empty", "--no-verify", "-m",
                 message)

    def check(self, rev_range="base..pr"):
        return subprocess.run([sys.executable, SCRIPT, rev_range],
                              cwd=self.repo, capture_output=True, text=True)

    def test_old_wrong_trailer_outside_range_passes(self):
        self.commit("new\n\nCo-Authored-By: Claude")
        self.commit("other agent\n\nCo-Authored-By: ZCode")
        r = self.check()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("2 commit(s)", r.stdout)

    def test_wrong_trailer_in_range_fails_naming_it(self):
        self.commit("fine\n\nCo-Authored-By: Claude")
        self.commit("bad one\n\nCo-Authored-By: Claude Opus 5 "
                    "<noreply@anthropic.com>")
        bad = self.git("rev-parse", "HEAD").strip()
        r = self.check()
        self.assertEqual(r.returncode, 1)
        self.assertIn(bad[:12], r.stderr)
        self.assertIn("bad one", r.stderr)
        self.assertNotIn("fine", r.stderr)

    def test_full_history_would_fail(self):
        # Sanity: the base commit really is a finding, so the passing
        # range test above passes because of the range, not by accident.
        self.assertEqual(self.check("experimental").returncode, 1)

    def test_empty_range_passes(self):
        self.assertEqual(self.check().returncode, 0)

    def test_bad_range_is_an_error(self):
        self.assertEqual(self.check("nosuch..pr").returncode, 2)


if __name__ == "__main__":
    unittest.main()
