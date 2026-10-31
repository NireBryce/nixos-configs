#!/usr/bin/env python3
"""Tests for ssh-key-check.sh, the pre-build unencrypted-key gate.

The checker's delicate property (its header documents it) is that it
separates encrypted from unencrypted keys using only ssh-keygen's exit
status, printing file paths and verdicts and never key material. These
tests generate real keypairs at runtime and hold the script to that: an
unencrypted key fails the gate by basename, an encrypted key passes, a
suppressed name passes with a visible notice, public halves and non-key
files are skipped, and no output ever contains key material.

Skips without ssh-keygen on PATH. Pure stdlib otherwise.
"""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "ssh-key-check.sh"


def run_check(directory, allow=None):
    env = dict(os.environ)
    env.pop("SSH_KEYS_ALLOW_UNENCRYPTED", None)
    if allow is not None:
        env["SSH_KEYS_ALLOW_UNENCRYPTED"] = allow
    return subprocess.run([str(SCRIPT), str(directory)],
                          capture_output=True, text=True, env=env)


@unittest.skipUnless(shutil.which("ssh-keygen"), "needs ssh-keygen on PATH")
class SshKeyCheck(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def gen_key(self, name, passphrase):
        subprocess.run(
            ["ssh-keygen", "-t", "ed25519", "-N", passphrase, "-C", "test",
             "-f", str(self.dir / name)],
            check=True, capture_output=True)

    def test_unencrypted_key_fails_loudly_without_leaking_material(self):
        self.gen_key("id_test", "")
        out = run_check(self.dir)
        self.assertNotEqual(out.returncode, 0, "an unencrypted key passed the gate")
        self.assertIn("UNENCRYPTED", out.stderr)
        self.assertIn("id_test", out.stderr)
        # No key material in the output, of either half: the public half is
        # discarded by the checker and the private half never leaves the file.
        self.assertNotIn("OPENSSH PRIVATE KEY", out.stderr)
        self.assertNotIn("ssh-ed25519", out.stderr)

    def test_encrypted_key_passes(self):
        self.gen_key("id_test", "a passphrase")
        out = run_check(self.dir)
        self.assertEqual(out.returncode, 0, out.stderr)

    def test_suppressed_name_passes_with_visible_notice(self):
        self.gen_key("id_test", "")
        out = run_check(self.dir, allow="id_test")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("allowed this run", out.stderr)
        self.assertIn("id_test", out.stderr)

    def test_suppression_of_a_different_name_still_fails(self):
        self.gen_key("id_test", "")
        out = run_check(self.dir, allow="id_someotherkey")
        self.assertNotEqual(out.returncode, 0,
                            "suppressing another file's name suppressed this one")

    def test_public_half_and_non_key_files_are_skipped(self):
        self.gen_key("id_real", "a passphrase")
        (self.dir / "id_real.pub").write_text("ssh-ed25519 AAAA test\n")
        (self.dir / "id_junk").write_text("not a key at all\n")
        out = run_check(self.dir)
        self.assertEqual(out.returncode, 0, out.stderr)

    def test_empty_directory_passes(self):
        out = run_check(self.dir)
        self.assertEqual(out.returncode, 0, out.stderr)

    def test_missing_directory_passes(self):
        out = run_check(self.dir / "does-not-exist")
        self.assertEqual(out.returncode, 0, out.stderr)


if __name__ == "__main__":
    unittest.main()
