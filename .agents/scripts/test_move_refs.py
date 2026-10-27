#!/usr/bin/env python3
"""Fixture tests for move_refs.py: a throwaway git repo, a move, and what the
rewriter does to every kind of reference. Each case is one the 2026-10-27
wiki reorganisation hit, including the two its first pass missed
(`<...>` links and `$root/`-prefixed paths).

Pure stdlib + git; runs in preflight and CI.
"""
import pathlib
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import move_refs  # noqa: E402


class Repo(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        self.git("init", "-q")
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")

    def git(self, *a):
        return subprocess.run(["git", "-C", str(self.root), *a], check=True,
                              capture_output=True, text=True).stdout

    def write(self, path, text):
        f = self.root / path
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(text)

    def read(self, path):
        return (self.root / path).read_text()

    def commit_all(self):
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "base")

    def move(self, old, new):
        (self.root / new).parent.mkdir(parents=True, exist_ok=True)
        self.git("mv", old, new)

    def run_tool(self, *extra):
        import io, contextlib
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = move_refs.main(["--root", str(self.root), *extra])
        self.assertEqual(rc, 0, out.getvalue())
        return out.getvalue()


class Links(Repo):
    def test_links_follow_a_moved_target_and_a_moved_source(self):
        self.write("wiki/hosts.md", "# hosts\n")
        self.write("wiki/other.md", "see [hosts](hosts.md#top) and [x](../README.md)\n")
        self.write("README.md", "# r\n")
        self.commit_all()
        self.move("wiki/hosts.md", "wiki/fleet/hosts.md")
        self.move("wiki/other.md", "wiki/misc/other.md")
        self.run_tool()
        self.assertEqual(self.read("wiki/misc/other.md"),
                         "see [hosts](../fleet/hosts.md#top) and [x](../../README.md)\n")

    def test_angle_bracket_links_are_rewritten(self):
        self.write("wiki/a.md", "[d](<../flake/doc/x.md>)\n")
        self.write("flake/doc/x.md", "x\n")
        self.commit_all()
        self.move("wiki/a.md", "wiki/sub/a.md")
        self.run_tool()
        self.assertEqual(self.read("wiki/sub/a.md"), "[d](<../../flake/doc/x.md>)\n")

    def test_visible_text_that_was_the_target_follows_it(self):
        self.write("wiki/a.md", "[b.md](b.md) and [`b.md`](b.md)\n")
        self.write("wiki/b.md", "b\n")
        self.commit_all()
        self.move("wiki/b.md", "wiki/deep/b.md")
        self.run_tool()
        self.assertEqual(self.read("wiki/a.md"),
                         "[deep/b.md](deep/b.md) and [`deep/b.md`](deep/b.md)\n")

    def test_urls_missing_targets_and_plain_anchors_are_untouched(self):
        body = "[u](https://x.org/wiki/b.md) [m](nope.md) [a](#frag)\n"
        self.write("wiki/a.md", body)
        self.write("wiki/b.md", "b\n")
        self.commit_all()
        self.move("wiki/b.md", "wiki/deep/b.md")
        self.run_tool()
        self.assertEqual(self.read("wiki/a.md"), body)

    def test_reference_style_definitions(self):
        self.write("wiki/a.md", "[b]: b.md\n")
        self.write("wiki/b.md", "b\n")
        self.commit_all()
        self.move("wiki/b.md", "wiki/deep/b.md")
        self.run_tool()
        self.assertEqual(self.read("wiki/a.md"), "[b]: deep/b.md\n")


class BarePaths(Repo):
    def setUp(self):
        super().setUp()
        self.write("wiki/scripts/check.py", "x = 1\n")
        self.write("wiki/scripts/other.py", "y = 1\n")
        self.write("wiki/hosts.md", "h\n")
        self.write("run.sh", "")
        self.commit_all()
        self.move("wiki/scripts/check.py", "wiki/meta/scripts/check.py")
        self.move("wiki/scripts/other.py", "wiki/meta/scripts/other.py")
        self.move("wiki/hosts.md", "wiki/fleet/hosts.md")

    def test_prose_and_code_mentions(self):
        self.write("run.sh", 'python3 wiki/scripts/check.py\nsee wiki/hosts.md.\n')
        self.run_tool()
        self.assertEqual(self.read("run.sh"),
                         'python3 wiki/meta/scripts/check.py\nsee wiki/fleet/hosts.md.\n')

    def test_variable_prefixed_and_dotdot_prefixed_paths(self):
        self.write("run.sh", '[ -f "$root/wiki/scripts/check.py" ]\n'
                             'ln ${root}/wiki/hosts.md\n`../../wiki/hosts.md`\n')
        self.run_tool()
        self.assertEqual(self.read("run.sh"),
                         '[ -f "$root/wiki/meta/scripts/check.py" ]\n'
                         'ln ${root}/wiki/fleet/hosts.md\n`../../wiki/fleet/hosts.md`\n')

    def test_a_longer_path_that_merely_ends_the_same_is_left_alone(self):
        body = "docs/wiki/hosts.md and wiki/hosts.md.bak\n"
        self.write("run.sh", body)
        self.run_tool()
        self.assertEqual(self.read("run.sh"), body)

    def test_whole_directory_is_inferred(self):
        self.write("run.sh", "ls wiki/scripts/ && ls wiki/scripts\n")
        self.run_tool()
        self.assertEqual(self.read("run.sh"),
                         "ls wiki/meta/scripts/ && ls wiki/meta/scripts\n")

    def test_partial_directory_move_is_not_a_directory_move(self):
        self.write("a/x.txt", "x\n")
        self.write("a/y.txt", "y\n")
        self.write("note.md", "a/ and a/y.txt\n")
        self.commit_all()
        self.move("a/x.txt", "b/x.txt")      # a/y.txt stays
        self.run_tool()
        self.assertEqual(self.read("note.md"), "a/ and a/y.txt\n")


class DryRunAndReview(Repo):
    def test_dry_run_writes_nothing_and_lists_files(self):
        self.write("wiki/a.md", "[b](b.md)\n")
        self.write("wiki/b.md", "b\n")
        self.commit_all()
        self.move("wiki/b.md", "wiki/deep/b.md")
        out = self.run_tool("--dry-run")
        self.assertEqual(self.read("wiki/a.md"), "[b](b.md)\n")
        self.assertIn("would rewrite 1 file", out)
        self.assertIn("wiki/a.md", out)

    def test_review_flags_built_paths_and_depth_in_moved_scripts(self):
        self.write("wiki/categories/x.md", "x\n")
        self.write("wiki/scripts/tool.py",
                   "import pathlib\nROOT = pathlib.Path(__file__).resolve().parents[2]\n"
                   "pages = ROOT / 'wiki' / 'categories'\n")
        self.commit_all()
        self.move("wiki/categories/x.md", "wiki/cs/categories/x.md")
        self.move("wiki/scripts/tool.py", "wiki/meta/scripts/tool.py")
        out = self.run_tool()
        self.assertIn("parents[2]", out)
        self.assertIn("builds a moved path from 'categories'", out)

    def test_no_renames_is_an_error_not_a_silent_success(self):
        self.write("a.md", "a\n")
        self.commit_all()
        self.assertEqual(move_refs.main(["--root", str(self.root)]), 2)

    def test_explicit_map_covers_a_move_git_did_not_detect(self):
        self.write("a.md", "a\n")
        self.write("n.md", "[a](a.md)\n")
        self.commit_all()
        self.git("mv", "a.md", "sub/a.md") if False else None
        self.move("a.md", "sub/a.md")
        self.run_tool("--map", "a.md=sub/a.md")
        self.assertEqual(self.read("n.md"), "[a](sub/a.md)\n")


if __name__ == "__main__":
    unittest.main()
