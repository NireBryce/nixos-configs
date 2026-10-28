#!/usr/bin/env python3
"""Fixture tests for book_nav.py.

The check exists so a chapter cannot drift from SUMMARY.md's order: each case
builds a tiny book, writes the blocks, and breaks one thing. Pure stdlib;
runs in preflight and CI.
"""
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import book_nav  # noqa: E402

SUMMARY = """# Summary

[Intro](intro.md)

# Part one

- [Alpha](alpha.md)
- [Beta](beta.md)

# Part two

- [Gamma](gamma.md)
"""


class Nav(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.src = Path(self.tmp.name) / "src"
        self.src.mkdir()
        (self.src / "SUMMARY.md").write_text(SUMMARY)
        for n, t in (("intro", "Intro"), ("alpha", "Alpha"), ("beta", "Beta"), ("gamma", "Gamma")):
            (self.src / f"{n}.md").write_text(f"# {t}\n\nBody of {n}.\n\n```\n# not a heading\n```\n")

    def read(self, n):
        return (self.src / f"{n}.md").read_text()

    def test_unwritten_book_fails_the_check_and_write_fixes_it(self):
        self.assertEqual(len(book_nav.check(self.src)), 4)
        self.assertEqual(len(book_nav.write(self.src)), 4)
        self.assertEqual(book_nav.check(self.src), [])
        self.assertEqual(book_nav.write(self.src), [])

    def test_block_sits_under_the_first_heading_and_keeps_the_body(self):
        book_nav.write(self.src)
        text = self.read("beta")
        self.assertTrue(text.startswith("# Beta\n\n<!-- book-nav"))
        self.assertIn("Body of beta.", text)
        self.assertEqual(text.count("book-nav: generated"), 1)

    def test_numbers_current_page_and_neighbours(self):
        book_nav.write(self.src)
        text = self.read("beta")
        self.assertIn("1. [Alpha](alpha.md)", text)
        self.assertIn("2. **Beta** (this page)", text)
        self.assertIn("3. [Gamma](gamma.md)", text)
        self.assertIn("[Intro](intro.md)", text)
        self.assertIn("← [Alpha](alpha.md) · [Gamma](gamma.md) →", text)
        self.assertIn("**Part one**", text)

    def test_first_and_last_pages_have_one_neighbour(self):
        book_nav.write(self.src)
        self.assertIn("[Alpha](alpha.md) →", self.read("intro"))
        self.assertNotIn("←", self.read("intro"))
        self.assertIn("← [Beta](beta.md)", self.read("gamma"))

    def test_reordering_summary_makes_every_block_stale(self):
        book_nav.write(self.src)
        (self.src / "SUMMARY.md").write_text(SUMMARY.replace(
            "- [Alpha](alpha.md)\n- [Beta](beta.md)", "- [Beta](beta.md)\n- [Alpha](alpha.md)"))
        found = book_nav.check(self.src)
        self.assertTrue(found and all("stale" in f for f in found))

    def test_hand_edited_block_is_found(self):
        book_nav.write(self.src)
        p = self.src / "alpha.md"
        p.write_text(p.read_text().replace("Alpha](alpha.md)", "Alpha](nowhere.md)", 1)
                     .replace("**Alpha**", "Alpha", 1))
        self.assertTrue(any("alpha.md" in f for f in book_nav.check(self.src)))

    def test_a_heading_inside_a_code_fence_is_not_the_anchor(self):
        (self.src / "alpha.md").write_text("```\n# fenced\n```\n\n# Real\n\ntext\n")
        book_nav.write(self.src)
        text = self.read("alpha")
        self.assertLess(text.index("# Real"), text.index("book-nav: generated"))


if __name__ == "__main__":
    unittest.main()
