#!/usr/bin/env python3
"""Fixture tests for pm-test-core.sh, the durandal `pm_test=core` loop.

The script writes /sys/power; each test points it at a fake directory
(PM_TEST_SYS) of plain files. The case it exists to catch is the one that
matters on the host: a freeze mid-loop leaves the last synced log line as
the only record, and a failed suspend must still put pm_test back to `none`.
Runs via `just preflight` and CI.
"""
import os
import shutil
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'pm-test-core.sh')


class PmTestCoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix='pm-test-core-')
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.sys = os.path.join(self.tmp, 'power')
        os.mkdir(self.sys)
        self.log = os.path.join(self.tmp, 'logs', 'pm.log')
        self.write('pm_test', '[none] core processors platform devices freezer\n')
        self.write('mem_sleep', 's2idle [deep]\n')
        self.write('state', '')

    def write(self, name, text):
        with open(os.path.join(self.sys, name), 'w') as f:
            f.write(text)

    def read(self, path):
        with open(path) as f:
            return f.read()

    def run_script(self, *args):
        env = dict(os.environ, PM_TEST_SYS=self.sys, PM_TEST_LOG=self.log,
                   PM_TEST_SKIP_ROOT='1')
        return subprocess.run([SCRIPT, *args], env=env, text=True,
                              capture_output=True)

    def test_clean_run_logs_every_cycle_and_restores_none(self):
        r = self.run_script('3')
        self.assertEqual(r.returncode, 0, r.stderr)
        log = self.read(self.log)
        for i in (1, 2, 3):
            self.assertIn(f'cycle {i}/3 suspending', log)
            self.assertIn(f'cycle {i}/3 resumed', log)
        self.assertIn('done, 3/3 clean', log)
        self.assertEqual(self.read(os.path.join(self.sys, 'pm_test')), 'none\n')

    def test_failed_suspend_still_restores_none(self):
        # `state` as a directory makes `echo mem > state` fail on cycle 1.
        os.remove(os.path.join(self.sys, 'state'))
        os.mkdir(os.path.join(self.sys, 'state'))
        r = self.run_script('3')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('cycle 1/3 suspending', self.read(self.log))
        self.assertNotIn('resumed', self.read(self.log))
        self.assertEqual(self.read(os.path.join(self.sys, 'pm_test')), 'none\n')

    def test_refuses_when_not_deep(self):
        self.write('mem_sleep', '[s2idle] deep\n')
        r = self.run_script('3')
        self.assertEqual(r.returncode, 1)
        self.assertIn('not [deep]', r.stderr)
        self.assertFalse(os.path.exists(self.log))

    def test_rejects_bad_cycle_count(self):
        self.assertEqual(self.run_script('0').returncode, 2)
        self.assertEqual(self.run_script('abc').returncode, 2)


if __name__ == '__main__':
    unittest.main()
