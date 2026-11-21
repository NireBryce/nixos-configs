#!/usr/bin/env python3
"""Fixture test for py_style.py: one file per rule it must flag, and a clean
file it must pass. Needs ruff on PATH (the dev shell has it); skips without.

Run: python3 flake/scripts/tests/test_py_style.py
"""
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import py_style  # noqa: E402

CASES = {
    "F401": "import os\n",
    "F541": "message = f'no placeholder'\nprint(message)\n",
    "F841": "def run():\n    unused = 1\n",
    "E702": "first = 1; second = 2\nprint(first, second)\n",
    "E731": "double = lambda value: value * 2\nprint(double(1))\n",
}
CLEAN_PY = "import os\n\n\ndef run():\n    return os.getcwd()\n"
CLEAN_NIX = "{\n    key = 1;\n}\n"


@unittest.skipUnless(shutil.which("ruff"), "ruff not on PATH")
class PyStyle(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def write(self, name, text):
        path = self.root / name
        path.write_text(text)
        return path

    def test_flags_each_python_rule(self):
        for rule, source in CASES.items():
            with self.subTest(rule=rule):
                path = self.write(f"case_{rule}.py", source)
                findings = py_style.ruff_findings([path])
                self.assertTrue(any(f": {rule} " in finding for finding in findings),
                                findings)
                self.assertEqual(py_style.cmd_check([path]), 1)

    def test_flags_trailing_whitespace_in_nix_and_python(self):
        for name, text in (("bad.nix", "{\n    key = 1; \n}\n"),
                           ("bad.py", "value = 1\t\nprint(value)\n")):
            with self.subTest(name=name):
                path = self.write(name, text)
                findings = py_style.whitespace_findings([path])
                self.assertEqual(len(findings), 1, findings)
                self.assertIn(":2:" if name == "bad.nix" else ":1:", findings[0])
                self.assertEqual(py_style.cmd_check([path]), 1)

    def test_ignores_trailing_whitespace_in_other_file_types(self):
        path = self.write("notes.md", "line with a break  \n")
        self.assertEqual(py_style.whitespace_findings([path]), [])

    def test_passes_clean_files(self):
        paths = [self.write("clean.py", CLEAN_PY), self.write("clean.nix", CLEAN_NIX)]
        self.assertEqual(py_style.cmd_check(paths), 0)

    def test_noqa_exempts_a_line(self):
        path = self.write("noqa.py", "import os  # noqa: F401\n")
        self.assertEqual(py_style.cmd_check([path]), 0)


if __name__ == "__main__":
    unittest.main()
