#!/usr/bin/env python3
"""Fixture tests for the Python that used to be embedded in bash.

deployed_baseline.py, diff_fingerprint.py and hm_collisions.py were
heredocs inside deployed-baseline.sh, diff-config.sh and hm-collisions.sh.
Those scripts need a real host (the store, /run/current-system, a nix eval),
so these tests feed the extracted functions fixture JSON and a temp $HOME
instead. Each case is one the code exists to get right: the password-source
branches (no hash is ever printed), the order-only vs real fingerprint
change, and the broot-style recursive directory that is not a collision.
Runs via `just preflight` and CI.
"""
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

SCRIPTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SCRIPTS)

import deployed_baseline  # noqa: E402
import diff_fingerprint  # noqa: E402
import hm_collisions  # noqa: E402


class KernelParams(unittest.TestCase):
    def test_joins_bootspec_params(self):
        boot = {"org.nixos.bootspec.v1": {"kernelParams": ["quiet", "loglevel=4"]}}
        self.assertEqual(deployed_baseline.kernel_params(boot), "quiet loglevel=4")

    def test_missing_params_is_empty_not_an_error(self):
        self.assertEqual(deployed_baseline.kernel_params({"org.nixos.bootspec.v1": {}}), "")


class UsersReport(unittest.TestCase):
    def lines(self, users, mutable):
        return deployed_baseline.users_report({"mutableUsers": mutable, "users": users})

    def test_password_source_never_the_hash(self):
        out = "\n".join(self.lines([
            {"name": "root", "uid": 0, "hashedPassword": "$6$SECRETHASH"},
            {"name": "elly", "uid": 1000, "hashedPasswordFile": "/run/secrets/pw"},
        ], False))
        self.assertIn("hashedPassword set in the config", out)
        self.assertIn("file /run/secrets/pw", out)
        self.assertNotIn("SECRETHASH", out)

    def test_root_listed_without_password_other_accounts_skipped(self):
        out = self.lines([{"name": "root", "uid": 0}, {"name": "nobody", "uid": 65534}], False)
        self.assertEqual(len(out), 3)  # mutableUsers line, blank, root
        self.assertIn("locked ('!'), mutableUsers=false", out[2])
        self.assertNotIn("nobody", "\n".join(out))

    def test_no_password_with_mutable_users_warns(self):
        out = self.lines([{"name": "root", "uid": 0}], True)
        self.assertIn("WARNING", out[-1])
        self.assertEqual(out[0], "mutableUsers: True")


class DiffFingerprint(unittest.TestCase):
    def test_identical_toplevel(self):
        fp = {"toplevel": "/nix/store/a.drv", "x": [1]}
        out = diff_fingerprint.report(fp, fp)
        self.assertIn("IDENTICAL", out[0])

    def test_order_only_vs_real_list_change(self):
        b = {"toplevel": "a", "pkgs": ["x", "y"], "kernel": ["p", "q"]}
        a = {"toplevel": "b", "pkgs": ["y", "x"], "kernel": ["p", "r"]}
        out = "\n".join(diff_fingerprint.report(b, a))
        self.assertIn("pkgs: SAME SET, ORDER ONLY (2 items)", out)
        self.assertIn("kernel: removed ['q']", out)
        self.assertIn("kernel: added   ['r']", out)

    def test_dict_reports_only_moved_keys(self):
        b = {"toplevel": "a", "h": {"same": 1, "gone": 1, "chg": 1}}
        a = {"toplevel": "b", "h": {"same": 1, "new": 1, "chg": 2}}
        out = "\n".join(diff_fingerprint.report(b, a))
        self.assertIn("h: removed 'gone'", out)
        self.assertIn("h: added   'new'", out)
        self.assertIn("h: changed 'chg'", out)
        self.assertNotIn("same", out)

    def test_differing_toplevel_with_no_sampled_difference(self):
        out = "\n".join(diff_fingerprint.report({"toplevel": "a"}, {"toplevel": "b"}))
        self.assertIn("no attribute in the fingerprint differs", out)


class HmCollisions(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = os.path.realpath(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def entries(self, **targets):
        return {k: {"target": k, "recursive": v} for k, v in targets.items()}

    def test_classification(self):
        os.makedirs(os.path.join(self.home, "recdir"))
        with open(os.path.join(self.home, "plain"), "w") as f:
            f.write("user's own file")
        os.makedirs(os.path.join(self.home, "plaindir"))
        os.symlink("/nix/store/fake-hm-file", os.path.join(self.home, "owned"))

        owned, absent, collisions, rec = hm_collisions.classify(
            self.entries(owned=False, missing=False, plain=False, recdir=True, plaindir=False),
            self.home)

        j = lambda n: os.path.join(self.home, n)
        self.assertEqual(owned, [j("owned")])
        self.assertEqual(absent, [j("missing")])
        self.assertEqual(rec, [j("recdir")])
        # a real directory is only expected when the entry is recursive
        self.assertEqual(sorted(collisions), sorted([j("plain"), j("plaindir")]))

    def run_main(self, entries):
        env = dict(os.environ, HOME=self.home)
        return subprocess.run(
            [sys.executable, os.path.join(SCRIPTS, "hm_collisions.py"), json.dumps(entries)],
            env=env, capture_output=True, text=True)

    def test_exit_status_follows_collisions(self):
        with open(os.path.join(self.home, "plain"), "w") as f:
            f.write("x")
        bad = self.run_main(self.entries(plain=False))
        self.assertEqual(bad.returncode, 1)
        self.assertIn("COLLISIONS -- HM does not own", bad.stdout)
        good = self.run_main(self.entries(missing=False))
        self.assertEqual(good.returncode, 0)
        self.assertIn("No collisions. This is a relink.", good.stdout)


class Cli(unittest.TestCase):
    def test_deployed_baseline_users_and_usage(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump({"mutableUsers": False, "users": [{"name": "root", "uid": 0}]}, f)
        self.addCleanup(os.unlink, f.name)
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.assertEqual(deployed_baseline.main(["x", "users", f.name]), 0)
        self.assertIn("mutableUsers: False", buf.getvalue())
        with redirect_stderr(io.StringIO()):
            self.assertEqual(deployed_baseline.main(["x"]), 2)


if __name__ == "__main__":
    unittest.main()
