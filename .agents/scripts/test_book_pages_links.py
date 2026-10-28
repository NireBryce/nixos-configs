#!/usr/bin/env python3
"""Fixture test for book_pages_links.py: a repo-relative link is rewritten, and
links that already work on a built site are not. Pure stdlib; runs in preflight."""
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import book_pages_links as bpl  # noqa: E402


class Rewrite(unittest.TestCase):
    def test_repo_relative_link_becomes_absolute_and_keeps_anchor(self):
        out = bpl.rewrite("see [x](../../wiki/a.md#b) now", "https://h/blob/e/")
        self.assertEqual(out, "see [x](https://h/blob/e/wiki/a.md#b) now")

    def test_chapter_and_external_links_are_untouched(self):
        text = "[a](glossary.md#x) [b](https://example.com/../../y) [c](../other.md)"
        self.assertEqual(bpl.rewrite(text), text)

    def test_main_rewrites_files_in_place_and_counts(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "a.md").write_text("[x](../../flake/f.nix)")
            (Path(d) / "b.md").write_text("[y](a.md)")
            self.assertEqual(bpl.main([d]), 0)
            self.assertEqual((Path(d) / "a.md").read_text(), f"[x]({bpl.BASE}flake/f.nix)")
            self.assertEqual((Path(d) / "b.md").read_text(), "[y](a.md)")


if __name__ == "__main__":
    unittest.main()
