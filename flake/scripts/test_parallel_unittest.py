#!/usr/bin/env python3
"""Fixture tests for parallel_unittest.py, the process-parallel runner the
slow suites use in place of unittest.main(). Each case writes a small test
module into a temp dir and runs it as a script with TEST_JOBS=4, checking
exit status and summary: green, a failure, a child that dies mid-test
(os._exit) or outlives TEST_UNIT_TIMEOUT, a module with no tests, a
setUpClass fixture run once per class, and the serial fallback. Pure
stdlib; runs in `just preflight`.
"""
import os
import pathlib
import subprocess
import sys
import tempfile
import textwrap
import unittest

HERE = pathlib.Path(__file__).resolve().parent


class Runner(unittest.TestCase):
    def run_module(self, body, *args, jobs="4", timeout=None):
        with tempfile.TemporaryDirectory() as d:
            mod = pathlib.Path(d) / "test_fixture.py"
            mod.write_text(textwrap.dedent(f"""\
                import os, sys, time, unittest
                sys.path.insert(0, {str(HERE)!r})
                import parallel_unittest
            """) + textwrap.dedent(body) + textwrap.dedent("""
                if __name__ == "__main__":
                    parallel_unittest.main()
            """))
            env = dict(os.environ, TEST_JOBS=jobs)
            if timeout:
                env["TEST_UNIT_TIMEOUT"] = str(timeout)
            return subprocess.run([sys.executable, str(mod), *args], cwd=d,
                                  capture_output=True, text=True, env=env,
                                  timeout=60)

    def test_green(self):
        r = self.run_module("""
            class T(unittest.TestCase):
                def test_a(self): pass
                def test_b(self): print("buffered, not shown")
                @unittest.skip("x")
                def test_c(self): pass
        """)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Ran 3 tests", r.stderr)
        self.assertIn("OK (skipped=1)", r.stderr)
        self.assertNotIn("buffered", r.stdout + r.stderr)

    def test_failure_is_reported_with_traceback(self):
        r = self.run_module("""
            class T(unittest.TestCase):
                def test_ok(self): pass
                def test_bad(self):
                    print("captured output")
                    self.assertEqual(1, 2)
        """)
        self.assertEqual(r.returncode, 1)
        self.assertIn("FAIL: test_bad", r.stderr)
        self.assertIn("AssertionError: 1 != 2", r.stderr)
        self.assertIn("captured output", r.stderr)
        self.assertIn("FAILED (failures=1)", r.stderr)

    def test_dead_child_is_an_error_not_a_hang(self):
        r = self.run_module("""
            class T(unittest.TestCase):
                def test_dies(self): os._exit(3)
                def test_fine(self): pass
        """)
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertIn("ERROR: test_dies", r.stderr)
        self.assertIn("exited with status 3", r.stderr)
        self.assertIn("Ran 2 tests", r.stderr)
        self.assertIn("FAILED (errors=1)", r.stderr)

    def test_child_over_the_timeout_is_killed(self):
        r = self.run_module("""
            class T(unittest.TestCase):
                def test_slow(self): time.sleep(30)
                def test_fine(self): pass
        """, timeout=2)
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertIn("ERROR: test_slow", r.stderr)
        self.assertIn("exceeded 2s and was killed", r.stderr)

    def test_no_tests_exits_5(self):
        r = self.run_module("x = 1\n")
        self.assertEqual(r.returncode, 5, r.stderr)
        self.assertIn("NO TESTS RAN", r.stderr)

    def test_class_fixture_runs_once_per_class(self):
        r = self.run_module("""
            class T(unittest.TestCase):
                calls = 0
                @classmethod
                def setUpClass(cls): cls.calls += 1
                def test_a(self): self.assertEqual(type(self).calls, 1)
                def test_b(self): self.assertEqual(type(self).calls, 1)
        """)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Ran 2 tests", r.stderr)

    def test_serial_fallback_with_arguments_or_one_job(self):
        body = """
            class T(unittest.TestCase):
                def test_a(self): pass
                def test_b(self): pass
        """
        r = self.run_module(body, "T.test_a")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Ran 1 test", r.stderr)
        self.assertNotIn("processes", r.stderr)
        r = self.run_module(body, jobs="1")
        self.assertIn("Ran 2 tests", r.stderr)
        self.assertNotIn("processes", r.stderr)


if __name__ == "__main__":
    unittest.main()
