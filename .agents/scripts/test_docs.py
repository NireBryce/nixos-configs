#!/usr/bin/env python3
"""Offline fixtures for doc_drift.py and doc_partition.py: a temp git repo
with dated docs and cited files. Drift must rank a doc whose cited file
changed after its date above one whose cited file did not; the partition
self-check must fail when a doc is dropped or duplicated, and siblings and
symlinks must stay together. Stdlib only.
"""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import doc_drift  # noqa: E402
import doc_partition  # noqa: E402

ENV = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
           GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
           GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")


def git(cwd, *args, date=None):
    env = dict(ENV)
    if date:
        env["GIT_AUTHOR_DATE"] = env["GIT_COMMITTER_DATE"] = f"{date}T12:00:00"
    subprocess.run(["git", "-C", str(cwd), *args], check=True, env=env,
                   capture_output=True)


def write(root, rel, text):
    p = Path(root) / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.r = Path(self.tmp.name)
        git(self.r, "init", "-q")
        write(self.r, "src/a/one.nix", "1\n")
        write(self.r, "src/a/two.nix", "1\n")
        write(self.r, "wiki/hot.md", "# hot\n\n_Last modified: 2026-01-10_\n\nSee `src/a/one.nix`.\n")
        write(self.r, "wiki/cold.md", "# cold\n\n_Last modified: 2026-01-10_\n\nSee `src/a/two.nix`, `gone/old.nix`.\n")
        write(self.r, "wiki/cold-for-agents.md", "cold terse\n")
        write(self.r, "wiki/cold-history.md", "cold old\n")
        write(self.r, "wiki/homelab/x.md", "x words here\n")
        write(self.r, ".agents/rules/r.md", '---\npaths:\n  - "**/*.nix"\n---\nSee [one](../../src/a/one.nix).\n')
        write(self.r, ".agents/skills/s/SKILL.md", "---\nname: s\n---\nbody\n")
        write(self.r, "AGENTS.md", "agents\n")
        (self.r / "wiki/README.md").symlink_to("hot.md")
        git(self.r, "add", "-A")
        git(self.r, "commit", "-qm", "init", date="2026-01-01")
        write(self.r, "src/a/one.nix", "2\n")
        git(self.r, "commit", "-qam", "change one", date="2026-02-01")

    def tearDown(self):
        self.tmp.cleanup()


class Drift(Fixture):
    def test_changed_cited_file_ranks_first(self):
        rows = doc_drift.rank(self.r)
        names = [r["doc"] for r in rows]
        hot, cold = rows[names.index("wiki/hot.md")], rows[names.index("wiki/cold.md")]
        self.assertEqual((hot["commits"], cold["commits"]), (1, 0))
        self.assertLess(names.index("wiki/hot.md"), names.index("wiki/cold.md"))
        self.assertEqual(hot["top"], [("src/a/one.nix", 1)])

    def test_missing_path_skipped_and_symlink_not_listed(self):
        rows = {r["doc"]: r for r in doc_drift.rank(self.r)}
        self.assertEqual(rows["wiki/cold.md"]["cited"], 1)  # gone/old.nix skipped
        self.assertNotIn("wiki/README.md", rows)

    def test_commit_on_doc_date_not_counted_and_git_date_fallback(self):
        rows = {r["doc"]: r for r in doc_drift.rank(self.r)}
        self.assertEqual(rows[".agents/rules/r.md"]["src"], "git")
        self.assertEqual(rows[".agents/rules/r.md"]["date"], "2026-01-01")
        self.assertEqual(rows[".agents/rules/r.md"]["commits"], 1)  # link target resolved

    def test_cli_exits_zero(self):
        self.assertEqual(doc_drift.main(["--root", str(self.r), "--top", "2"]), 0)


class Partition(Fixture):
    def test_every_doc_once_and_units_together(self):
        docs, us, groups = doc_partition.partition(self.r, 3)
        self.assertEqual(doc_partition.verify(docs, groups, us), [])
        where = {f: i for i, g in enumerate(groups) for f in g["files"]}
        self.assertEqual(len({where["wiki/cold.md"], where["wiki/cold-for-agents.md"],
                              where["wiki/cold-history.md"]}), 1)
        self.assertEqual(where["wiki/README.md"], where["wiki/hot.md"])

    def test_selfcheck_catches_dropped_and_duplicated(self):
        docs, us, groups = doc_partition.partition(self.r, 3)
        victim = next(g for g in groups if "AGENTS.md" in g["files"])
        victim["files"].remove("AGENTS.md")
        self.assertTrue(any("AGENTS.md: unassigned" in p
                            for p in doc_partition.verify(docs, groups, us)))
        victim["files"].append("AGENTS.md")
        other = next(g for g in groups if g is not victim)
        other["files"].append("AGENTS.md")
        self.assertTrue(any("assigned twice" in p
                            for p in doc_partition.verify(docs, groups, us)))

    def test_cli_ok_exit_zero(self):
        self.assertEqual(doc_partition.main(["--root", str(self.r), "--agents", "2"]), 0)


if __name__ == "__main__":
    unittest.main()
