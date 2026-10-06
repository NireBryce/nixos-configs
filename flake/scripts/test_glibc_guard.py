#!/usr/bin/env python3
"""Fixture tests for glibc-guard.sh, the `just switch` glibc-change warning.

The guard reads live host state -- /run/booted-system, /run/current-system,
the store, an eval of the flake -- none of which CI has. So each test builds
fake system trees in a temp directory (just `etc/pam.d/login` naming a
pam_unix.so path) and puts stub `nix` and `nix-store` on PATH: `nix eval`
prints the "new" glibc version, `nix-store -q --references` prints a glibc
store path for whichever linux-pam package it is asked about. The script's
GLIBC_GUARD_BOOTED / GLIBC_GUARD_CURRENT point it at the fakes.

The case it exists to catch is the real one from 2026-10-05/06 on
nire-durandal: booted on glibc 2.42, switching to 2.44. Runs via
`just preflight` and CI.
"""
import os
import shutil
import stat
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
GUARD = os.path.join(HERE, 'glibc-guard.sh')
HASH = 'a' * 32


def pam_pkg(tag):
    return f'/nix/store/{tag * 32}-linux-pam-1.7.2'


class GlibcGuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix='glibc-guard-test-')
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.bin = os.path.join(self.tmp, 'bin')
        os.mkdir(self.bin)
        self.refs = {}  # linux-pam store path -> glibc store path

    def stub(self, name, body):
        path = os.path.join(self.bin, name)
        with open(path, 'w') as f:
            f.write('#!/usr/bin/env bash\n' + body)
        os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC)

    def system(self, name, tag, glibc):
        """A fake system whose pam_unix.so comes from linux-pam <tag>,
        linked against glibc <glibc> ('2.42-84'), or None for no pam.d."""
        root = os.path.join(self.tmp, name)
        os.makedirs(os.path.join(root, 'etc', 'pam.d'))
        if glibc is not None:
            with open(os.path.join(root, 'etc', 'pam.d', 'login'), 'w') as f:
                f.write(f'auth sufficient {pam_pkg(tag)}/lib/security/pam_unix.so likeauth\n')
            self.refs[pam_pkg(tag)] = f'/nix/store/{HASH}-glibc-{glibc}'
        return root

    def run_guard(self, new, booted, current):
        if new is None:
            self.stub('nix', 'exit 1\n')
        else:
            self.stub('nix', f'printf %s {new}\n')
        cases = ''.join(
            f'    {pkg}) echo /nix/store/{"b" * 32}-shadow-4.17; echo {glibc} ;;\n'
            for pkg, glibc in self.refs.items())
        self.stub('nix-store', f'case "$3" in\n{cases}esac\n')
        env = dict(os.environ,
                   PATH=self.bin + os.pathsep + os.environ['PATH'],
                   GLIBC_GUARD_BOOTED=booted,
                   GLIBC_GUARD_CURRENT=current)
        p = subprocess.run([GUARD, '/flake', 'host'], env=env,
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, 'guard must never fail a switch')
        return p.stderr

    def test_real_case_glibc_242_to_244_warns(self):
        booted = self.system('booted-system', 'c', '2.42-84')
        out = self.run_guard('2.44', booted, booted)
        self.assertIn('WARNING: glibc changes to 2.44', out)
        self.assertIn('booted 2.42', out)
        self.assertIn('just boot', out)

    def test_same_version_is_silent(self):
        booted = self.system('booted-system', 'c', '2.44-25')
        self.assertEqual(self.run_guard('2.44', booted, booted), '')

    def test_same_version_different_build_is_silent(self):
        # A rebuild with a new patch level adds no symbol versions.
        booted = self.system('booted-system', 'c', '2.44-20')
        current = self.system('current-system', 'd', '2.44-25')
        self.assertEqual(self.run_guard('2.44', booted, current), '')

    def test_only_current_stale_after_earlier_reboot_names_current(self):
        booted = self.system('booted-system', 'c', '2.44-25')
        current = self.system('current-system', 'd', '2.42-84')
        out = self.run_guard('2.44', booted, current)
        self.assertIn('current 2.42', out)
        self.assertNotIn('booted', out.split('use:')[1].split('After')[0])

    def test_same_system_listed_once(self):
        booted = self.system('booted-system', 'c', '2.42-84')
        current = os.path.join(self.tmp, 'current-system')
        os.symlink(booted, current)
        out = self.run_guard('2.44', booted, current)
        self.assertEqual(out.count('2.42'), 1)

    def test_eval_failure_says_so(self):
        booted = self.system('booted-system', 'c', '2.42-84')
        out = self.run_guard(None, booted, booted)
        self.assertIn('could not evaluate', out)
        self.assertNotIn('WARNING', out)

    def test_unreadable_pam_says_so(self):
        booted = self.system('booted-system', 'c', None)
        out = self.run_guard('2.44', booted, booted)
        self.assertIn('could not read', out)
        self.assertNotIn('WARNING', out)

    def test_missing_systems_are_skipped(self):
        missing = os.path.join(self.tmp, 'nope')
        self.assertEqual(self.run_guard('2.44', missing, missing), '')


if __name__ == '__main__':
    unittest.main()
