#!/usr/bin/env python3
"""Fixtures for debug-suspend-short-sleep.py.

Dry runs write the log without suspending. The real path is exercised with a
fake `sudo` and `systemctl` on PATH and a fake suspend_stats directory: the
fake `systemctl` returns at once, as the real one does, and a background job
raises the success counter later (a resume), or never does (a hang or a missed
alarm). `report` must flag a cycle with no resolution, ignore a torn last line,
and treat a `timeout` or `failed` cycle as unresolved with its reason.
Stdlib only.
"""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "debug-suspend-short-sleep.py"

FAKE_SUDO = "#!/bin/sh\nexit ${FAKE_SUDO_STATUS:-0}\n"
FAKE_SYSTEMCTL = """#!/bin/sh
# Returns at once, like `systemctl suspend`; a later job is the resume.
if [ -n "$FAKE_RESUME_AFTER" ]; then
    (sleep "$FAKE_RESUME_AFTER"; n=$(cat "$SUSPEND_STATS_DIR/success"); echo $((n + 1)) > "$SUSPEND_STATS_DIR/success") > /dev/null 2>&1 &
fi
exit 0
"""


def run(state_home, *args, extra_env=None, path_prefix=None):
    environment = {**os.environ, "XDG_STATE_HOME": str(state_home)}
    if path_prefix:
        environment["PATH"] = f"{path_prefix}:{environment['PATH']}"
    environment.update(extra_env or {})
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
        env=environment,
    )


class ShortSleep(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.state_home = self.root / "state"
        self.log = self.state_home / "debug-suspend" / "short-sleep.log"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, body in (("sudo", FAKE_SUDO), ("systemctl", FAKE_SYSTEMCTL)):
            (self.bin / name).write_text(body)
            (self.bin / name).chmod(0o755)
        self.stats = self.root / "stats"
        self.stats.mkdir()
        (self.stats / "success").write_text("7\n")

    def tearDown(self):
        self.temp.cleanup()

    def real_run(self, *args, **env):
        environment = {"SUSPEND_STATS_DIR": str(self.stats), **env}
        return run(self.state_home, "run", "--settle", "0", "--min-delay", "1", *args,
                   extra_env=environment, path_prefix=str(self.bin))

    def test_dry_run_logs_every_cycle_and_report_counts_them(self):
        result = run(self.state_home, "run", "--delays", "5,10", "--min-delay", "1",
                     "--rounds", "3", "--dry-run", "--seed", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = self.log.read_text().splitlines()
        self.assertEqual(sum(" suspend " in line for line in lines), 6)
        self.assertEqual(sum(" resumed " in line for line in lines), 6)
        report = run(self.state_home, "report")
        self.assertIn("   5 s        3        3           0", report.stdout)
        self.assertNotIn("unresolved:", report.stdout)

    def test_delays_under_the_minimum_are_refused(self):
        result = run(self.state_home, "run", "--delays", "5,30", "--dry-run")
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.log.exists())

    @unittest.skipIf(os.geteuid() == 0, "real runs refuse root")
    def test_resume_is_detected_from_the_success_counter(self):
        result = self.real_run("--delays", "1", "--rounds", "1", FAKE_RESUME_AFTER="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.log.read_text()
        self.assertIn(" resumed ", text)
        slept = float(text.split("slept=")[1].split()[0])
        self.assertGreaterEqual(slept, 1.0)
        self.assertNotIn("unresolved:", run(self.state_home, "report").stdout)

    @unittest.skipIf(os.geteuid() == 0, "real runs refuse root")
    def test_a_suspend_that_never_resumes_is_a_timeout_not_a_resume(self):
        # systemctl returns at once; if the counter never rises the old code
        # logged `resumed` anyway. It must not.
        result = self.real_run("--delays", "1", "--rounds", "1", "--wait-extra", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.log.read_text()
        self.assertIn(" timeout ", text)
        self.assertNotIn(" resumed ", text)
        report = run(self.state_home, "report")
        self.assertIn("(timeout)", report.stdout)

    @unittest.skipIf(os.geteuid() == 0, "real runs refuse root")
    def test_a_failed_rtcwake_stops_the_run_and_is_not_a_hang(self):
        result = self.real_run("--delays", "1", "--rounds", "2", FAKE_SUDO_STATUS="1")
        self.assertEqual(result.returncode, 1)
        text = self.log.read_text()
        self.assertEqual(text.count(" suspend "), 1)
        self.assertIn(" failed ", text)
        self.assertIn("(failed)", run(self.state_home, "report").stdout)

    def test_a_wake_after_the_deadline_is_late_not_never(self):
        # The process is frozen while the machine sleeps, so the first check
        # after a long sleep can find the clock past the deadline with the
        # counter already risen. That must be "late", not "never".
        import importlib.util
        from unittest import mock

        spec = importlib.util.spec_from_file_location("short_sleep", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with mock.patch.object(module, "read_success_count", return_value=8), \
                mock.patch.object(module.time, "time", return_value=1000.0):
            self.assertEqual(module.wait_for_resume(7, 10.0), "late")
        with mock.patch.object(module, "read_success_count", return_value=7), \
                mock.patch.object(module.time, "time", return_value=1000.0):
            self.assertEqual(module.wait_for_resume(7, 10.0), "never")
        with mock.patch.object(module, "read_success_count", return_value=8), \
                mock.patch.object(module.time, "time", return_value=1.0):
            self.assertEqual(module.wait_for_resume(7, 10.0), "resumed")

    def test_cycle_without_a_resolution_is_unresolved(self):
        self.log.parent.mkdir(parents=True)
        self.log.write_text(
            "t suspend run=a cycle=1 delay=30 wake=rtc\n"
            "t resumed run=a cycle=1 delay=30 slept=31.0\n"
            "t suspend run=a cycle=2 delay=60 wake=rtc\n"
        )
        report = run(self.state_home, "report")
        self.assertIn("unresolved: run a cycle 2 delay 60 s (hung or interrupted)", report.stdout)
        self.assertNotIn("cycle 1 delay", report.stdout)

    def test_a_torn_last_line_does_not_crash_report(self):
        self.log.parent.mkdir(parents=True)
        self.log.write_text(
            "t suspend run=a cycle=1 delay=30 wake=rtc\n"
            "t resumed run=a cycle=1 delay=30 slept=31.0\n"
            "t suspend run=a cyc"
        )
        report = run(self.state_home, "report")
        self.assertEqual(report.returncode, 0, report.stderr)
        self.assertIn("  30 s        1        1           0", report.stdout)

    def test_each_round_holds_every_delay_once(self):
        run(self.state_home, "run", "--delays", "5,10,20", "--min-delay", "1",
            "--rounds", "4", "--dry-run", "--seed", "7")
        delays = [
            int(part.split("=")[1])
            for line in self.log.read_text().splitlines()
            if " suspend " in line
            for part in line.split()
            if part.startswith("delay=")
        ]
        for start in range(0, 12, 3):
            self.assertEqual(sorted(delays[start:start + 3]), [5, 10, 20])

    def test_report_without_log_exits_2(self):
        self.assertEqual(run(self.state_home, "report").returncode, 2)


if __name__ == "__main__":
    unittest.main()
