#!/usr/bin/env python3
"""Fixture test for rename_names.py: each case that broke a rename by hand
during the 2026-11-15 pass, and the refusals that stop a bad rename.

Run: python3 .agents/scripts/test_rename_names.py
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rename_names  # noqa: E402


def renamed(source, spec, **mapping):
    return rename_names.rename_in_source(source, spec, mapping)[0]


class Rename(unittest.TestCase):
    def test_renames_parameters_variables_and_comprehensions(self):
        source = "def run(r):\n    p = [m for m in r]\n    return p\n"
        out = renamed(source, "run", r="rows", p="picked", m="item")
        self.assertEqual(
            out, "def run(rows):\n    picked = [item for item in rows]\n    return picked\n")

    def test_leaves_strings_comments_and_attributes_alone(self):
        source = "def run(r):\n    # r is the row\n    return 'r', r.r\n"
        out = renamed(source, "run", r="row")
        self.assertEqual(out, "def run(row):\n    # r is the row\n    return 'r', row.r\n")

    def test_leaves_keyword_arguments_in_calls_alone(self):
        source = "def run(r):\n    return call(r=r)\n"
        out = renamed(source, "run", r="row")
        self.assertEqual(out, "def run(row):\n    return call(r=row)\n")

    def test_names_after_a_multibyte_character_on_the_same_line(self):
        # ast columns are UTF-8 byte offsets: the `§` before `{n}` shifted a
        # character-based edit by one and missed the name.
        source = "def run(n):\n    return f\"§{n} and {n}\"\n"
        out = renamed(source, "run", n="number")
        self.assertEqual(out, "def run(number):\n    return f\"§{number} and {number}\"\n")

    def test_renames_except_names_and_import_aliases(self):
        source = ("import json as j\n\n\ndef run():\n    try:\n        j.loads('')\n"
                  "    except ValueError as e:\n        raise RuntimeError(e)\n")
        out = renamed(source, "*", e="error", j="jsonlib")
        self.assertIn("import json as jsonlib", out)
        self.assertIn("jsonlib.loads('')", out)
        self.assertIn("except ValueError as error:", out)
        self.assertIn("RuntimeError(error)", out)

    def test_scope_limits_the_rename_to_one_function(self):
        source = "def one(r):\n    return r\n\n\ndef two(r):\n    return r\n"
        out = renamed(source, "two", r="row")
        self.assertIn("def one(r):", out)
        self.assertIn("def two(row):", out)

    def test_dotted_scope_reaches_a_method_and_its_nested_function(self):
        source = ("class Box:\n    def run(self, r):\n        def inner(r):\n"
                  "            return r\n        return inner(r)\n")
        out = renamed(source, "Box.run", r="row")
        self.assertNotIn("(r)", out)
        self.assertEqual(out.count("row"), 4)

    def test_refuses_a_name_already_used_in_the_scope(self):
        with self.assertRaises(ValueError) as caught:
            renamed("def run(r, row):\n    return r, row\n", "run", r="row")
        self.assertIn("already used", str(caught.exception))

    def test_refuses_an_ambiguous_scope_and_accepts_name_at_line(self):
        source = ("class A:\n    def setUp(self):\n        d = 1\n\n\n"
                  "class B:\n    def setUp(self):\n        d = 2\n")
        with self.assertRaises(ValueError) as caught:
            renamed(source, "setUp", d="data")
        self.assertIn("ambiguous", str(caught.exception))
        out = renamed(source, "setUp@7", d="data")
        self.assertIn("d = 1", out)
        self.assertIn("data = 2", out)

    def test_refuses_a_missing_scope_and_an_invalid_name(self):
        with self.assertRaises(ValueError):
            renamed("x = 1\n", "nope", x="y")
        with self.assertRaises(ValueError):
            renamed("def run(r):\n    pass\n", "run", r="not valid")


class ListNames(unittest.TestCase):
    def test_groups_one_character_names_by_function(self):
        source = "def one(r):\n    return r\n\n\ndef two(result):\n    return result\n"
        self.assertEqual(rename_names.short_names_by_function(source), {"one": [1, 2]})


class Callers(unittest.TestCase):
    def test_finds_renamed_parameters(self):
        old = "def feature(cwd, n=1):\n    pass\n\n\ndef other(a):\n    pass\n"
        new = "def feature(cwd, count=1):\n    pass\n\n\ndef other(a):\n    pass\n"
        self.assertEqual(rename_names.renamed_parameters(old, new),
                         {"feature": {"n": "count"}})

    def test_finds_a_keyword_call_to_the_old_name_only(self):
        renamed_map = {"feature": {"n": "count"}}
        texts = {"t.py": "self.feature(repo, n=2)\nself.feature(repo, count=2)\n"
                         "other(n=3)\n"}
        self.assertEqual(rename_names.keyword_calls(renamed_map, texts),
                         ["t.py:1: feature n="])


class CommandLine(unittest.TestCase):
    def test_rename_writes_the_file_and_a_collision_writes_nothing(self):
        script = Path(rename_names.__file__)
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "sample.py"
            target.write_text("def run(r):\n    return r\n")
            done = subprocess.run([sys.executable, str(script), "rename", str(target),
                                   "run", "r=row"], capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, done.stderr)
            self.assertEqual(target.read_text(), "def run(row):\n    return row\n")
            target.write_text("def run(r, row):\n    return r\n")
            done = subprocess.run([sys.executable, str(script), "rename", str(target),
                                   "run", "r=row"], capture_output=True, text=True)
            self.assertEqual(done.returncode, 1)
            self.assertEqual(target.read_text(), "def run(r, row):\n    return r\n")


if __name__ == "__main__":
    unittest.main()
