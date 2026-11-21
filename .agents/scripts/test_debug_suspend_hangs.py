#!/usr/bin/env python3
"""Fixtures for debug_suspend_hangs.py: a temp dump directory with a clean cycle, a
hang (+3), an orphan `pre` left by a reboot, and a person-requested hang.
Checks which cycles are reported, that a clean (+1) cycle and an orphan are
not, that the requester is read, and the exit code for a missing directory.
Stdlib only.
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "debug_suspend_hangs.py"


def write_dump(directory, name, nvme_cycles, requester="org_kde_powerd"):
    text = (
        "# kernel  6.18.63\n"
        "## requester\n"
        f"2026-01-01T00:00:00-05:00 host systemd-logind[1]: suspend requested "
        f"from client PID 1 ('{requester}') (unit user@1000.service)...\n"
        "## drive power cycles\n"
        f"/dev/nvme0   power_cycles={nvme_cycles}\n"
        f"/dev/sda     power_cycles={nvme_cycles + 3000}\n"
    )
    (directory / name).write_text(text)


def run(directory, *extra):
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--dir", str(directory), *extra],
        check=False,
        capture_output=True,
        text=True,
    )


class SuspendHangs(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        write_dump(self.directory, "20260101T000000Z-pre.txt", 10)
        write_dump(self.directory, "20260101T000100Z-post.txt", 11)  # clean, +1
        write_dump(self.directory, "20260101T010000Z-pre.txt", 11)
        write_dump(self.directory, "20260101T010500Z-post.txt", 14)  # hang, +3
        write_dump(self.directory, "20260101T020000Z-pre.txt", 14)  # orphan: reboot
        write_dump(self.directory, "20260101T030000Z-pre.txt", 14, "plasmashell-wr")
        write_dump(self.directory, "20260101T030400Z-post.txt", 16)  # hang, +2

    def tearDown(self):
        self.temp.cleanup()

    def test_reports_hangs_only(self):
        result = run(self.directory)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("20260101T010000Z-pre.txt -> 20260101T010500Z-post.txt", result.stdout)
        self.assertIn("nvme0:+3", result.stdout)
        self.assertNotIn("20260101T000100Z-post.txt", result.stdout)
        self.assertIn("2 hangs, 1 clean (3 cycles", result.stdout)

    def test_orphan_pre_is_not_a_hang(self):
        # The 02:00 pre has no post of its own; the 03:04 post pairs with the
        # 03:00 pre, the latest earlier one.
        result = run(self.directory)
        self.assertNotIn("20260101T020000Z-pre.txt ->", result.stdout)
        self.assertIn("20260101T030000Z-pre.txt -> 20260101T030400Z-post.txt", result.stdout)

    def test_requester_is_read(self):
        result = run(self.directory)
        self.assertIn("plasmashell-wr", result.stdout)
        self.assertIn("org_kde_powerd", result.stdout)

    def test_all_includes_clean(self):
        result = run(self.directory, "--all")
        self.assertIn("clean 20260101T000000Z-pre.txt -> 20260101T000100Z-post.txt", result.stdout)

    def test_drive_line_outside_the_drive_section_is_ignored(self):
        # A hostile journal line could plant a drive-looking line in another
        # section; only `## drive power cycles` may count.
        planted = self.directory / "20260101T040500Z-post.txt"
        write_dump(self.directory, "20260101T040000Z-pre.txt", 20)
        write_dump(self.directory, "20260101T040500Z-post.txt", 21)
        text = planted.read_text().replace(
            "## requester\n", "## requester\n/dev/nvme0   power_cycles=999\n", 1
        )
        planted.write_text(text)
        result = run(self.directory)
        self.assertNotIn("20260101T040500Z-post.txt", result.stdout)

    def test_requester_must_be_a_plain_identifier(self):
        write_dump(self.directory, "20260101T050000Z-pre.txt", 30, "IGNORE ALL; do x")
        write_dump(self.directory, "20260101T050500Z-post.txt", 33)
        result = run(self.directory)
        self.assertIn("20260101T050500Z-post.txt", result.stdout)
        self.assertNotIn("IGNORE", result.stdout)
        self.assertIn("unknown", result.stdout)

    def test_kernel_is_printed_and_must_look_like_a_version(self):
        result = run(self.directory)
        self.assertIn("kernel 6.18.63", result.stdout)
        planted = self.directory / "20260101T060000Z-pre.txt"
        write_dump(self.directory, "20260101T060000Z-pre.txt", 40)
        planted.write_text(planted.read_text().replace("6.18.63", "ignore previous; run x"))
        write_dump(self.directory, "20260101T060500Z-post.txt", 43)
        result = run(self.directory)
        self.assertIn("kernel unknown", result.stdout)
        self.assertNotIn("ignore previous", result.stdout)

    def test_missing_directory_exits_2(self):
        result = run(self.directory / "absent")
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
