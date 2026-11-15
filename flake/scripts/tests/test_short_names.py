#!/usr/bin/env python3
"""Fixture test for short_names.py: every kind of one-character name it
exists to catch, and the names it must leave alone.

Run: python3 flake/scripts/tests/test_short_names.py
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import short_names  # noqa: E402


def names_in(source):
    return [name for _, name in short_names.find_sites(source)]


class FindSites(unittest.TestCase):
    def test_catches_assignment_loop_and_comprehension_names(self):
        source = (
            "r = 1\n"
            "for p in range(3):\n"
            "    pass\n"
            "values = [m for m in range(3)]\n"
        )
        self.assertEqual(sorted(names_in(source)), ["m", "p", "r"])  # one per name per line

    def test_catches_parameters_and_lambda_parameters(self):
        source = "def run(a, *b, c=1, **d):\n    return lambda e: e\n"
        self.assertEqual(sorted(set(names_in(source))), ["a", "b", "c", "d", "e"])

    def test_catches_except_names(self):
        source = "try:\n    pass\nexcept OSError as e:\n    raise\n"
        self.assertEqual(names_in(source), ["e"])

    def test_catches_function_class_and_import_alias_names(self):
        source = "import json as j\n\n\ndef f():\n    pass\n\n\nclass C:\n    pass\n"
        self.assertEqual(sorted(names_in(source)), ["C", "f", "j"])

    def test_ignores_underscore_and_longer_names(self):
        source = "for _ in range(3):\n    pass\nresult = [item for item in 'ab']\n"
        self.assertEqual(names_in(source), [])

    def test_ignores_letters_in_strings_and_comments(self):
        source = "# r = 1\ntext = 'p = 2'\nf'{text}'\n"
        self.assertEqual(names_in(source), [])

    def test_ignores_attribute_names(self):
        source = "result = point.x + point.y\n"
        self.assertEqual(names_in(source), [])

    def test_catches_names_inside_f_strings(self):
        source = "n = 2\nprint(f'{n}')\n"
        self.assertEqual(names_in(source), ["n", "n"])

    def test_pragma_skips_only_its_line(self):
        source = "x = 1  # short-name: ok\ny = 2\n"
        self.assertEqual(names_in(source), ["y"])

    def test_reports_line_numbers(self):
        self.assertEqual(short_names.find_sites("ok = 1\nr = 2\n"), [(2, "r")])

    def test_syntax_error_propagates(self):
        with self.assertRaises(SyntaxError):
            short_names.find_sites("def (:\n")


if __name__ == "__main__":
    unittest.main()
