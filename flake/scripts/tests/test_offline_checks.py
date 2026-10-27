#!/usr/bin/env python3
"""Tests for offline_checks.py and the exit-75 contract of with-nix-tools.sh.

The failure these guard against is a hook that quietly checks nothing: the
staged-file checks must fire on a broken file, with-nix-tools.sh must say
"cannot run" (75) rather than "failed" when nix is absent, and the offline
preflight must stay in step with the real one -- a nix-dependent step that
is not named in NEEDS_NIX would fail on every nix-less push, and a name that
no longer exists in preflight is a stale exemption.

Pure stdlib + git; runs in preflight and CI.
"""
import importlib.util
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location(
    "offline_checks", REPO / "flake/scripts/offline_checks.py")
oc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oc)


class StagedChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self._repo = oc.REPO
        oc.REPO = self.root
        self.addCleanup(setattr, oc, "REPO", self._repo)

    def problems(self, path, text):
        f = self.root / path
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(text)
        subprocess.run(["git", "-C", str(self.root), "add", path], check=True)
        return oc.check_staged_file(path)

    def test_broken_python_is_caught_and_good_python_passes(self):
        self.assertTrue(self.problems("a.py", "def f(:\n"))
        self.assertEqual(self.problems("b.py", "x = 1\n"), [])

    def test_broken_bash_is_caught(self):
        self.assertTrue(self.problems("a.sh", "if then fi (\n"))
        self.assertTrue(self.problems(".githooks/pre-x", "if [\n"))
        self.assertEqual(self.problems("b.sh", "echo ok\n"), [])

    def test_json_and_toml(self):
        self.assertTrue(self.problems("a.json", "{nope"))
        self.assertEqual(self.problems("b.json", "{}"), [])
        self.assertTrue(self.problems("a.toml", "x = = 1\n"))
        self.assertEqual(self.problems("b.toml", "x = 1\n"), [])

    @unittest.skipUnless(shutil.which("nix-instantiate"), "no nix-instantiate")
    def test_broken_nix_is_caught(self):
        self.assertTrue(self.problems("a.nix", "{ a = ; }"))
        self.assertEqual(self.problems("b.nix", "{ a = 1; }"), [])

    def test_the_index_version_is_checked_not_the_worktree(self):
        self.assertTrue(self.problems("a.py", "def f(:\n"))
        (self.root / "a.py").write_text("x = 1\n")   # fixed, but not re-staged
        self.assertTrue(oc.check_staged_file("a.py"))


class PreflightClassification(unittest.TestCase):
    def setUp(self):
        self.steps = oc.classify(oc.preflight_lines())

    def test_every_needs_nix_entry_is_still_a_preflight_step(self):
        labels = {label for _, label, _ in self.steps}
        stale = sorted(set(oc.NEEDS_NIX) - labels)
        self.assertEqual(stale, [], "NEEDS_NIX names a step preflight no longer runs")

    def test_python_steps_run_and_the_rest_are_skipped_with_a_reason(self):
        for argv, label, reason in self.steps:
            if argv is None:
                self.assertTrue(reason, label)
            else:
                self.assertIsNone(reason)
                self.assertTrue((REPO / label).is_file(), label)

    def test_wiki_lint_runs_without_the_generated_check(self):
        lint = [a for a, l, _ in self.steps
                if l == "wiki/meta/scripts/check_wiki.py"]
        self.assertEqual(len(lint), 1)
        self.assertIn("--skip=generated", lint[0])

    def test_something_actually_runs(self):
        self.assertGreater(sum(1 for a, _, _ in self.steps if a), 5)


class WithNixToolsContract(unittest.TestCase):
    def test_exits_75_when_there_is_neither_the_tools_nor_nix(self):
        script = REPO / "flake/scripts/with-nix-tools.sh"
        bash = shutil.which("bash")
        with tempfile.TemporaryDirectory() as d:
            env = {"PATH": d}      # an empty directory: no statix, no nix
            r = subprocess.run([bash, str(script), ".", "true"], env=env,
                               capture_output=True, text=True)
        self.assertEqual(r.returncode, 75, r.stderr)

    def test_passes_the_commands_own_status_through_when_tools_exist(self):
        script = REPO / "flake/scripts/with-nix-tools.sh"
        bash = shutil.which("bash")
        with tempfile.TemporaryDirectory() as d:
            for tool in ("statix", "deadnix"):
                p = pathlib.Path(d, tool)
                p.write_text("#!/bin/sh\n")
                p.chmod(0o755)
            env = {"PATH": f"{d}:{os.path.dirname(bash)}:/usr/bin:/bin"}
            r = subprocess.run([bash, str(script), ".", "sh", "-c", "exit 3"],
                               env=env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 3, r.stderr)


if __name__ == "__main__":
    unittest.main()
