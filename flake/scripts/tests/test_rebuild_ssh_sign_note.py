#!/usr/bin/env python3
"""Tests for the one-time git-signing note in rebuild.sh.

After a successful NixOS `boot` or `switch`, rebuild.sh prints a note to run
`just retire-old-ssh-sign` when the evaluated config carries the new
`git-ssh-sign` wrapper and the old script's override or file still exists. It
must stay silent otherwise, so it stops appearing once the cleanup is done,
and a failed rebuild must keep its exit status and print no note.

`nix` and `nh` are stubs on PATH: nix answers the darwin check ("no") and the
gpg.ssh.program eval from an environment variable and fails any other eval;
nh exits with STUB_NH_STATUS. HOME is a throwaway directory, and the flake is
a throwaway git repo, so nothing real is read or changed.

Skips off Linux, where rebuild.sh refuses a NixOS host. Pure stdlib.
"""
import os
import platform
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "rebuild.sh"
NOTE = "ONE-TIME NOTE"
NEW_WRAPPER = "/nix/store/aaaa-git-ssh-sign"


@unittest.skipUnless(platform.system() == "Linux", "rebuild.sh needs Linux")
class RebuildSshSignNote(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.home = root / "home"
        (self.home / ".config" / "git").mkdir(parents=True)
        self.old_script = self.home / ".config" / "git" / "ssh-sign"
        self.old_script.write_text("#!/bin/sh\n")
        self.flake = root / "flake"
        self.flake.mkdir()
        self.env = dict(os.environ, HOME=str(self.home),
                        GIT_CONFIG_GLOBAL="/dev/null",
                        GIT_CONFIG_SYSTEM="/dev/null")
        subprocess.run(["git", "-C", str(self.flake), "init", "-q"],
                       check=True, env=self.env)
        self.set_override(str(self.old_script))
        bindir = root / "bin"
        bindir.mkdir()
        (bindir / "nix").write_text(
            "#!/usr/bin/env bash\n"
            'case "$*" in\n'
            '    *darwinConfigurations*) echo no ;;\n'
            '    *gpg.ssh.program*) echo "$STUB_WRAPPER" ;;\n'
            "    *) exit 1 ;;\n"
            "esac\n")
        (bindir / "nh").write_text(
            '#!/usr/bin/env bash\nexit "${STUB_NH_STATUS:-0}"\n')
        for stub in ("nix", "nh"):
            (bindir / stub).chmod(0o755)
        self.env["PATH"] = f"{bindir}:{os.environ['PATH']}"
        self.env["STUB_WRAPPER"] = NEW_WRAPPER

    def set_override(self, value):
        subprocess.run(["git", "-C", str(self.flake), "config", "--local",
                        "gpg.ssh.program", value], check=True, env=self.env)

    def rebuild(self, action, **extra_env):
        return subprocess.run(
            [str(SCRIPT), action, str(self.flake), "nire-test"],
            capture_output=True, text=True,
            env=dict(self.env, **extra_env))

    def test_boot_prints_the_note_and_says_to_reboot(self):
        result = self.rebuild("boot")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(NOTE, result.stderr)
        self.assertIn("After you reboot", result.stderr)

    def test_switch_prints_the_note(self):
        result = self.rebuild("switch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(NOTE, result.stderr)
        self.assertNotIn("After you reboot", result.stderr)

    def test_silent_once_the_cleanup_is_done(self):
        subprocess.run(["git", "-C", str(self.flake), "config", "--local",
                        "--unset", "gpg.ssh.program"], check=True,
                       env=self.env)
        self.old_script.unlink()
        for action in ("boot", "switch"):
            with self.subTest(action=action):
                result = self.rebuild(action)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn(NOTE, result.stderr)

    def test_silent_when_the_config_lacks_the_new_wrapper(self):
        result = self.rebuild("boot", STUB_WRAPPER="")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(NOTE, result.stderr)

    def test_failed_rebuild_keeps_its_status_and_prints_no_note(self):
        for action in ("boot", "switch"):
            with self.subTest(action=action):
                result = self.rebuild(action, STUB_NH_STATUS="3")
                self.assertEqual(result.returncode, 3)
                self.assertNotIn(NOTE, result.stderr)

    def test_build_prints_no_note(self):
        result = self.rebuild("build")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(NOTE, result.stderr)


if __name__ == "__main__":
    unittest.main()
