#!/usr/bin/env python3
"""Tests for init-ssh-handle.sh, which recreates the YubiKey handle file.

`ssh-keygen -K` needs hardware and downloads every resident credential on
every connected authenticator, so the tests shadow ssh-keygen on PATH with a
wrapper: `-K` copies two fixed keypairs into the current directory (standing
in for the YubiKey's credential and an unrelated one), everything else goes
to the real ssh-keygen. The script must install only the credential whose
fingerprint is asked for, and must not clobber an existing handle.

Skips without ssh-keygen on PATH. Pure stdlib otherwise.
"""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "init-ssh-handle.sh"
REAL = shutil.which("ssh-keygen")


@unittest.skipUnless(REAL, "needs ssh-keygen on PATH")
class InitSshHandle(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.home = root / "home"
        self.home.mkdir()
        self.ssh = self.home / ".ssh"
        fixed = root / "fixed"
        fixed.mkdir()
        for name, comment in (("id_ed25519_sk_rk", "wanted"),
                              ("id_ed25519_sk_rk_other", "other")):
            subprocess.run([REAL, "-q", "-t", "ed25519", "-N", "", "-C",
                            comment, "-f", str(fixed / name)], check=True)
        bindir = root / "bin"
        bindir.mkdir()
        wrapper = bindir / "ssh-keygen"
        wrapper.write_text(
            "#!/usr/bin/env bash\n"
            'if [[ "$1" == "-K" ]]; then\n'
            f'    cp "{fixed}"/* .\n'
            "    exit 0\n"
            "fi\n"
            f'exec "{REAL}" "$@"\n')
        wrapper.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=f"{bindir}:{os.environ['PATH']}")
        self.wanted = subprocess.run(
            [REAL, "-lf", str(fixed / "id_ed25519_sk_rk.pub")],
            capture_output=True, text=True, check=True).stdout.split()[1]
        self.wanted_priv = (fixed / "id_ed25519_sk_rk").read_text()

    def run_script(self, *args):
        return subprocess.run([str(SCRIPT), *args], capture_output=True,
                              text=True, env=self.env)

    def test_installs_only_the_matching_credential(self):
        out = self.run_script("--fingerprint", self.wanted)
        self.assertEqual(out.returncode, 0, out.stderr)
        dest = self.ssh / "id_ed25519_sk"
        self.assertEqual(dest.read_text(), self.wanted_priv)
        self.assertEqual(oct(dest.stat().st_mode & 0o777), "0o600")
        self.assertIn(" wanted", (self.ssh / "id_ed25519_sk.pub").read_text())
        self.assertEqual(sorted(p.name for p in self.ssh.iterdir()),
                         ["id_ed25519_sk", "id_ed25519_sk.pub"])
        self.assertNotIn("PRIVATE KEY", out.stderr)

    def test_no_match_installs_nothing(self):
        out = self.run_script("--fingerprint", "SHA256:notakey")
        self.assertNotEqual(out.returncode, 0)
        self.assertIn("no downloaded credential", out.stderr)
        self.assertFalse((self.ssh / "id_ed25519_sk").exists())
        self.assertFalse((self.ssh / "id_ed25519_sk.pub").exists())

    def test_default_fingerprint_comes_from_ssh_nix(self):
        # The stub's keys never match the YubiKey line in ssh.nix, so the
        # script must get as far as the match step, having derived a real
        # SHA256 fingerprint from ssh.nix (not failed parsing it).
        out = self.run_script()
        self.assertNotEqual(out.returncode, 0)
        self.assertIn("looking for SHA256:", out.stderr)
        self.assertIn("no downloaded credential", out.stderr)

    def test_existing_handle_is_not_overwritten(self):
        self.ssh.mkdir()
        (self.ssh / "id_ed25519_sk").write_text("keep me")
        out = self.run_script("--fingerprint", self.wanted)
        self.assertNotEqual(out.returncode, 0)
        self.assertIn("--force", out.stderr)
        self.assertEqual((self.ssh / "id_ed25519_sk").read_text(), "keep me")

    def test_force_overwrites(self):
        self.ssh.mkdir()
        (self.ssh / "id_ed25519_sk").write_text("old")
        out = self.run_script("--fingerprint", self.wanted, "--force")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual((self.ssh / "id_ed25519_sk").read_text(), self.wanted_priv)


if __name__ == "__main__":
    unittest.main()
