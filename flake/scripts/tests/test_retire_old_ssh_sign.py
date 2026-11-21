#!/usr/bin/env python3
"""Tests for retire-old-ssh-sign.sh, which removes the repo-local override
that keeps the hand-made ~/.config/git/ssh-sign wrapper in use.

Each test builds a throwaway HOME and git repo. The script must change nothing
without --apply, unset only an override equal to the old script's path, leave
any other value alone, and delete the old script only with --remove-script.

Skips without git on PATH. Pure stdlib otherwise.
"""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "retire-old-ssh-sign.sh"


@unittest.skipUnless(shutil.which("git"), "needs git on PATH")
class RetireOldSshSign(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.home = root / "home"
        (self.home / ".config" / "git").mkdir(parents=True)
        self.old_script = self.home / ".config" / "git" / "ssh-sign"
        self.old_script.write_text("#!/bin/sh\n")
        self.repo = root / "repo"
        self.repo.mkdir()
        self.env = dict(os.environ, HOME=str(self.home),
                        GIT_CONFIG_GLOBAL="/dev/null",
                        GIT_CONFIG_SYSTEM="/dev/null")
        subprocess.run(["git", "-C", str(self.repo), "init", "-q"],
                       check=True, env=self.env)

    def set_override(self, value):
        subprocess.run(["git", "-C", str(self.repo), "config", "--local",
                        "gpg.ssh.program", value], check=True, env=self.env)

    def override(self):
        result = subprocess.run(
            ["git", "-C", str(self.repo), "config", "--local", "--get",
             "gpg.ssh.program"], capture_output=True, text=True, env=self.env)
        return result.stdout.strip()

    def run_script(self, *args):
        return subprocess.run([str(SCRIPT), *args, str(self.repo)],
                              capture_output=True, text=True, env=self.env)

    def test_dry_run_changes_nothing(self):
        self.set_override(str(self.old_script))
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("would remove", result.stdout)
        self.assertEqual(self.override(), str(self.old_script))
        self.assertTrue(self.old_script.exists())

    def test_apply_unsets_the_old_override_only(self):
        self.set_override(str(self.old_script))
        result = self.run_script("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.override(), "")
        self.assertTrue(self.old_script.exists())

    def test_other_value_is_left_alone(self):
        self.set_override("/somewhere/else/sign")
        result = self.run_script("--apply", "--remove-script")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("left alone", result.stdout)
        self.assertEqual(self.override(), "/somewhere/else/sign")

    def test_remove_script_deletes_it_when_no_repo_points_at_it(self):
        self.set_override(str(self.old_script))
        result = self.run_script("--apply", "--remove-script")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.override(), "")
        self.assertFalse(self.old_script.exists())

    def test_remove_script_needs_apply(self):
        result = self.run_script("--remove-script")
        self.assertEqual(result.returncode, 2)
        self.assertTrue(self.old_script.exists())

    def test_tilde_spelling_is_removed_not_left_pointing_at_a_deleted_file(self):
        self.set_override("~/.config/git/ssh-sign")
        result = self.run_script("--apply", "--remove-script")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.override(), "")
        self.assertFalse(self.old_script.exists())

    def test_symlink_to_the_old_script_keeps_the_script(self):
        link = self.home / "link-to-sign"
        link.symlink_to(self.old_script)
        self.set_override(str(link))
        result = self.run_script("--apply", "--remove-script")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.override(), str(link))
        self.assertTrue(self.old_script.exists())
        self.assertIn("kept", result.stdout)

    def test_multiple_values_are_reported_and_fail_the_run(self):
        self.set_override("/other")
        subprocess.run(["git", "-C", str(self.repo), "config", "--local",
                        "--add", "gpg.ssh.program", str(self.old_script)],
                       check=True, env=self.env)
        result = self.run_script("--apply", "--remove-script")
        self.assertEqual(result.returncode, 1)
        self.assertTrue(self.old_script.exists())

    def test_a_path_that_is_not_a_repo_fails_the_run(self):
        result = subprocess.run([str(SCRIPT), str(self.home / "nope")],
                                capture_output=True, text=True, env=self.env)
        self.assertEqual(result.returncode, 1)
        self.assertIn("not a git repository", result.stderr)

    def test_help_stops_before_the_shell_options(self):
        result = subprocess.run([str(SCRIPT), "--help"], capture_output=True,
                                text=True, env=self.env)
        self.assertEqual(result.returncode, 0)
        self.assertNotIn("set -euo", result.stdout)

    def test_check_is_silent_and_exits_4_while_the_override_is_set(self):
        self.set_override(str(self.old_script))
        result = self.run_script("--check")
        self.assertEqual(result.returncode, 4)
        self.assertEqual(result.stdout + result.stderr, "")

    def test_check_exits_4_while_only_the_old_script_remains(self):
        result = self.run_script("--check")
        self.assertEqual(result.returncode, 4)

    def test_check_exits_0_once_both_are_gone(self):
        self.set_override(str(self.old_script))
        self.run_script("--apply", "--remove-script")
        result = self.run_script("--check")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout + result.stderr, "")

    def test_check_ignores_an_unrelated_override(self):
        self.old_script.unlink()
        self.set_override("/somewhere/else/sign")
        result = self.run_script("--check")
        self.assertEqual(result.returncode, 0)

    def test_no_override_is_a_clean_no_op(self):
        result = self.run_script("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no repo-local gpg.ssh.program", result.stdout)


if __name__ == "__main__":
    unittest.main()
