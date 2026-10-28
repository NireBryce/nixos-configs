#!/usr/bin/env python3
"""Fixture tests for book_lint.py and book_render.py.

Each check is exercised on a small book that has the defect it exists to
catch, and on one that does not, so a check that stops firing fails here
rather than passing silently. Pure stdlib; runs in preflight and CI.
"""
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import book_lint  # noqa: E402
import book_render  # noqa: E402


class Book(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.src = self.root / "src"
        self.src.mkdir()

    def write(self, name, text):
        (self.src / name).write_text(text)

    def summary(self, *names):
        self.write("SUMMARY.md", "# Summary\n\n" + "".join(f"- [{n}]({n})\n" for n in names))

    def findings(self):
        return book_lint.check(self.src)


class Links(Book):
    def test_a_clean_book_has_no_findings(self):
        self.summary("a.md", "b.md")
        self.write("a.md", "# A\n\nSee [b](b.md#the-thing) and [here](#a).\n")
        self.write("b.md", "# B\n\n## The thing\n")
        self.assertEqual(self.findings(), [])

    def test_a_missing_file_is_found(self):
        self.summary("a.md")
        self.write("a.md", "# A\n\n[gone](gone.md)\n")
        self.assertTrue(any(f.startswith("link") and "gone.md" in f for f in self.findings()))

    def test_a_bad_anchor_is_found_and_a_good_one_is_not(self):
        self.summary("a.md", "b.md")
        self.write("a.md", "# A\n\n[x](b.md#nope) [y](b.md#real-heading)\n")
        self.write("b.md", "# B\n\n## Real `heading`\n")
        found = self.findings()
        self.assertEqual(len([f for f in found if f.startswith("anchor")]), 1)
        self.assertIn("#nope", found[0])

    def test_links_inside_code_are_not_checked(self):
        self.summary("a.md")
        self.write("a.md", "# A\n\n```\n[x](missing.md)\n```\n`[y](missing.md)`\n")
        self.assertEqual(self.findings(), [])

    def test_summary_must_list_every_chapter_and_only_real_ones(self):
        self.summary("a.md", "ghost.md")
        self.write("a.md", "# A\n")
        self.write("orphan.md", "# O\n")
        found = " ".join(self.findings())
        self.assertIn("ghost.md, which does not exist", found)
        self.assertIn("orphan.md is not listed", found)


class Volatile(Book):
    def check_one(self, line):
        self.summary("a.md")
        self.write("a.md", f"# A\n\n{line}\n")
        return [f for f in self.findings() if f.startswith("volatile")]

    def test_dates_and_counts_of_hosts_hooks_and_files_are_found(self):
        self.assertTrue(self.check_one("Changed on 2026-10-28."))
        self.assertTrue(self.check_one("Two hosts wipe the root."))
        self.assertTrue(self.check_one("It runs three hooks."))
        self.assertTrue(self.check_one("There are 12 files."))

    def test_the_pair_idiom_for_files_and_modules_passes(self):
        self.assertEqual(self.check_one("If two files share a name, evaluation stops."), [])
        self.assertEqual(self.check_one("A throwaway flake with two modules."), [])

    def test_larger_counts_of_files_still_fail(self):
        self.assertTrue(self.check_one("It rewrote three files."))

    def test_code_and_the_ignore_marker_are_exempt(self):
        self.assertEqual(self.check_one("`three hooks` in code, 2026-10-28 here.".replace("2026-10-28 here", "x")), [])
        self.assertEqual(self.check_one("Three hooks. <!-- book-lint: ignore -->"), [])

    def test_prose_without_numbers_passes(self):
        self.assertEqual(self.check_one("The hooks under the hooks directory run first."), [])


class Cli(Book):
    def run_cli(self, *args):
        out = io.StringIO()
        with redirect_stdout(out):
            rc = book_lint.main(["--book", str(self.root), *args])
        return rc, out.getvalue()

    def test_check_exits_nonzero_on_findings_and_zero_when_clean(self):
        self.summary("a.md")
        self.write("a.md", "# A\n\n[gone](gone.md)\n")
        self.assertEqual(self.run_cli("check")[0], 1)
        self.write("a.md", "# A\n")
        self.assertEqual(self.run_cli("check")[0], 0)

    def test_prose_reports_without_failing(self):
        self.summary("a.md")
        self.write("a.md", "# A\n\n" + ("word " * 130).strip() + ".\n")
        rc, out = self.run_cli("prose")
        self.assertEqual(rc, 0)
        self.assertIn("130", out)


class Render(unittest.TestCase):
    def test_inlines_css_and_drops_scripts(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d)
            (out / "css").mkdir()
            (out / "css" / "general-abc.css").write_text("body{color:red}")
            (out / "css" / "chrome-abc.css").write_text(".x{y:z}")
            (out / "print.html").write_text(
                '<html><head><link rel="stylesheet" href="css/general-abc.css">'
                '<script>alert(1)</script></head><body><h1>Hi</h1></body></html>')
            html = book_render.render(out)
        self.assertIn("body{color:red}", html)
        self.assertIn(".x{y:z}", html)
        self.assertNotIn("<script", html)
        self.assertNotIn('rel="stylesheet"', html)
        self.assertIn("<h1>Hi</h1>", html)

    def test_a_missing_print_html_says_how_to_build(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(SystemExit) as e:
                book_render.render(d)
        self.assertIn("mdbook build", str(e.exception))


if __name__ == "__main__":
    unittest.main()
