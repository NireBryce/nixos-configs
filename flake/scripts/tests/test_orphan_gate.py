#!/usr/bin/env python3
"""End-to-end check that `nix flake check --no-build` fails on an orphan.

Why this exists: checks.nix sets dirs-as-categories' `checkOrphans` to "eval".
With "build" (what the v0.4.0 migration note suggested) the same tree passed
`just check`, because a check that fails in its builder never fails under
--no-build. Every other test here feeds modules.py a canned graph or stubs
`nix`, so none could see the difference; this one runs the real flake check on
a copy of the tree with one orphan added, and on an unmodified copy as the
control.

Runs in preflight and CI (about 30s each: two flake checks). Skips without
`nix`. Checks the host's own system only, not --all-systems: the orphan check
is platform independent, and `just check` covers every host.
"""
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

FLAKE = Path(__file__).resolve().parents[2]
HEADER = """# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ nixos = { }; }
"""
ORPHAN = "general-config/zz-orphan-gate/inner/zz-orphan-module.nix"


def flake_check(tree):
    return subprocess.run(
        ["nix", "flake", "check", "--no-build", "--no-write-lock-file", f"path:{tree}"],
        capture_output=True, text=True)


@unittest.skipUnless(shutil.which("nix"), "needs nix on PATH")
class OrphanGate(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.tree = Path(cls.tmp.name) / "flake"
        shutil.copytree(FLAKE, cls.tree, ignore=shutil.ignore_patterns(".git", "result*"))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_an_orphan_fails_the_flake_check_under_no_build(self):
        control = flake_check(self.tree)
        self.assertEqual(control.returncode, 0, control.stderr[-2000:])
        orphan = self.tree / "modules" / ORPHAN
        orphan.parent.mkdir(parents=True)
        orphan.write_text(HEADER)
        try:
            out = flake_check(self.tree)
        finally:
            shutil.rmtree(orphan.parent.parent)
        self.assertNotEqual(out.returncode, 0, "an orphan passed `nix flake check --no-build`")
        self.assertIn("reached by no includes or enables", out.stderr)
        self.assertIn("zz-orphan-module", out.stderr)


if __name__ == "__main__":
    unittest.main()
