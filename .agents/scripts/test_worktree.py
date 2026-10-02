#!/usr/bin/env python3
"""Offline fixtures for worktree.py (new, prune) and preflight-each.sh, in
throwaway repos with a bare `origin` and a fake `gh` (prints nothing: no
PR recorded) on PATH. prune is checked for what it removes AND what it
must leave: dirty, unlanded, pushed-but-empty, too-fresh, outside the
root, the main checkout. preflight-each runs a stand-in check
(PREFLIGHT_EACH_CMD) and must leave no worktree behind, on success,
failure, and SIGTERM. Stdlib only; runs in `just preflight`.
"""
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
WT = HERE / "worktree.py"
EACH = HERE / "preflight-each.sh"
GIT_ENV = dict(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
               GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], check=True,
                          capture_output=True, text=True,
                          env=dict(os.environ, **GIT_ENV)).stdout.strip()


def commit(cwd, name, text="x\n", msg=None):
    (Path(cwd) / name).write_text(text)
    git(cwd, "add", name)
    git(cwd, "commit", "-qm", msg or f"add {name}")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.t = Path(os.path.realpath(self.tmp.name))
        bin_ = self.t / "bin"
        bin_.mkdir()
        (bin_ / "gh").write_text("#!/bin/sh\nexit 0\n")
        (bin_ / "gh").chmod(0o755)
        self.env = dict(os.environ, PATH=f"{bin_}:{os.environ['PATH']}",
                        **GIT_ENV)
        self.env.pop("AGENT_SCRATCH", None)
        self.origin = self.t / "origin.git"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "experimental",
                        str(self.origin)], check=True)
        self.repo = self.t / "repo"
        subprocess.run(["git", "init", "-q", "-b", "experimental",
                        str(self.repo)], check=True)
        commit(self.repo, "base")
        git(self.repo, "remote", "add", "origin", str(self.origin))
        git(self.repo, "push", "-qu", "origin", "experimental")
        self.root = self.t / "scratch"

    def tearDown(self):
        self.tmp.cleanup()

    def run_(self, *args, cwd=None, script=WT, env=None):
        return subprocess.run([str(script), *args], cwd=cwd or self.repo,
                              env=env or self.env, text=True,
                              capture_output=True)

    def new(self, branch, *more):
        r = self.run_("new", branch, "--root", str(self.root), *more)
        self.assertEqual(r.returncode, 0, r.stderr)
        return Path(r.stdout.strip())

    def worktrees(self):
        return [l[9:] for l in git(self.repo, "worktree", "list",
                                   "--porcelain").splitlines()
                if l.startswith("worktree ")]

    def branches(self):
        return git(self.repo, "branch", "--format=%(refname:short)").split()


class New(Base):
    def test_creates_and_prints_only_the_path(self):
        r = self.run_("new", "feat/a-b", "--root", str(self.root))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, f"{self.root / 'wt-a-b'}\n")
        p = self.root / "wt-a-b"
        self.assertEqual(git(p, "branch", "--show-current"), "feat/a-b")
        self.assertEqual(git(p, "rev-parse", "HEAD"),
                         git(self.repo, "rev-parse", "origin/experimental"))

    def test_env_root_and_base(self):
        commit(self.repo, "local-only")  # local experimental ahead of origin
        env = dict(self.env, AGENT_SCRATCH=str(self.root))
        r = self.run_("new", "plain", "experimental", env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        p = self.root / "wt-plain"
        self.assertEqual(r.stdout.strip(), str(p))
        self.assertEqual(git(p, "rev-parse", "HEAD"),
                         git(self.repo, "rev-parse", "experimental"))

    def test_refuses_existing_branch_path_or_remote(self):
        self.new("feat/a")
        r = self.run_("new", "feat/a", "--root", str(self.root))
        self.assertEqual(r.returncode, 1)
        self.assertIn("refs/heads/feat/a already exists", r.stderr)
        r = self.run_("new", "fix/a", "--root", str(self.root))  # same dir
        self.assertEqual(r.returncode, 1)
        self.assertIn("wt-a already exists", r.stderr)
        self.assertNotIn("fix/a", self.branches())
        git(self.repo, "push", "-q", "origin", "experimental:refs/heads/feat/r")
        r = self.run_("new", "feat/r", "--root", str(self.root))
        self.assertEqual(r.returncode, 1)
        self.assertIn("refs/remotes/origin/feat/r already exists", r.stderr)


class Prune(Base):
    def setUp(self):
        super().setUp()
        # landed: one commit, rebased onto origin's experimental (new SHA)
        self.landed = self.new("feat/landed")
        commit(self.landed, "l")
        git(self.landed, "push", "-q", "origin", "HEAD:refs/heads/feat/landed")
        git(self.repo, "cherry-pick", "-x",  # -x: a new SHA, as a rebase merge gives
            git(self.landed, "rev-parse", "HEAD"))
        git(self.repo, "push", "-q", "origin", "experimental")
        git(self.repo, "push", "-q", "origin", "--delete", "feat/landed")
        # unlanded, pushed
        self.open_ = self.new("feat/open")
        commit(self.open_, "o")
        git(self.open_, "push", "-q", "origin", "HEAD:refs/heads/feat/open")
        # landed but dirty
        self.dirty = self.new("feat/dirty")
        (self.dirty / "base").write_text("changed\n")
        # fresh: nothing ahead, never pushed
        self.fresh = self.new("feat/fresh")
        # pushed, nothing ahead
        self.pushed = self.new("feat/pushed")
        git(self.pushed, "push", "-q", "origin", "HEAD:refs/heads/feat/pushed")
        # detached at the trunk: what ship-land leaves
        self.detached = self.root / "wt-detached"
        git(self.repo, "worktree", "add", "-q", "--detach",
            str(self.detached), "origin/experimental")
        # outside the root: never touched, even though it's fresh
        self.outside = self.t / "elsewhere"
        git(self.repo, "worktree", "add", "-q", str(self.outside), "-b",
            "feat/outside", "origin/experimental")

    def prune(self, *more):
        return self.run_("prune", "--root", str(self.root), "--min-age", "0",
                         *more)

    def line(self, out, path):
        return next(l for l in out.splitlines() if f"  {path}  " in l)

    def test_dry_run_reports_and_removes_nothing(self):
        before = self.worktrees()
        r = self.prune()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.worktrees(), before)
        out = r.stdout
        self.assertTrue(self.line(out, self.landed).startswith("remove"))
        self.assertIn("1 ahead, landed; not on origin", self.line(out, self.landed))
        self.assertIn("NOT landed; on origin", self.line(out, self.open_))
        self.assertTrue(self.line(out, self.dirty).startswith("keep"))
        self.assertIn("dirty", self.line(out, self.dirty))
        self.assertTrue(self.line(out, self.fresh).startswith("remove"))
        self.assertIn("pushed, nothing ahead", self.line(out, self.pushed))
        self.assertTrue(self.line(out, self.detached).startswith("remove"))
        self.assertNotIn(str(self.outside), out)
        self.assertNotIn(f"  {self.repo}  ", out)
        self.assertIn("3 removable; nothing done", out)

    def test_yes_removes_exactly_the_safe_ones(self):
        r = self.prune("--yes")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        left = set(self.worktrees())
        for p in (self.landed, self.fresh, self.detached):
            self.assertNotIn(str(p), left)
            self.assertFalse(p.exists())
        for p in (self.open_, self.dirty, self.pushed, self.outside, self.repo):
            self.assertIn(str(p), left)
        b = self.branches()
        self.assertNotIn("feat/landed", b)
        self.assertNotIn("feat/fresh", b)
        for kept in ("feat/open", "feat/dirty", "feat/pushed", "feat/outside"):
            self.assertIn(kept, b)
        self.assertEqual((self.dirty / "base").read_text(), "changed\n")

    def test_min_age_protects_a_new_worktree(self):
        r = self.run_("prune", "--root", str(self.root), "--yes")  # default 60m
        self.assertIn("touched 0m ago", self.line(r.stdout, self.fresh))
        self.assertTrue(self.fresh.exists())
        self.assertFalse(self.landed.exists())

    def test_never_removes_the_worktree_it_runs_in(self):
        r = self.run_("prune", "--root", str(self.root), "--min-age", "0",
                      "--yes", cwd=self.fresh)
        self.assertIn("the worktree this runs in", r.stdout)
        self.assertTrue(self.fresh.exists())


class PreflightEach(Base):
    CHECK = ('if [ -e bad ]; then echo "FAIL  step"; echo boom; exit 1; fi;'
             ' echo "preflight passed: 3 steps"')

    def setUp(self):
        super().setUp()
        git(self.repo, "switch", "-qc", "feat/e")
        commit(self.repo, "one", msg="feat: one")
        commit(self.repo, "bad", msg="feat: breaks it")
        git(self.repo, "rm", "-q", "bad")
        git(self.repo, "commit", "-qm", "fix: unbreak")

    def each(self, check, *args):
        return self.run_(*args, script=EACH,
                         env=dict(self.env, PREFLIGHT_EACH_CMD=check))

    def test_one_line_per_commit_and_failure_tail(self):
        r = self.each(self.CHECK)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        lines = r.stdout.splitlines()
        self.assertIn("3 commits in origin/experimental..HEAD", lines[0])
        self.assertRegex(lines[1], r"^ok   [0-9a-f]{8} feat: one  \(3 steps, \d+s\)$")
        self.assertRegex(lines[2], r"^FAIL [0-9a-f]{8} feat: breaks it")
        self.assertIn("     boom", lines)
        self.assertRegex(lines[-1], r"^ok   [0-9a-f]{8} fix: unbreak")
        self.assertEqual(self.worktrees(), [str(self.repo)])

    def test_all_green_and_range(self):
        r = self.each(self.CHECK, "HEAD~3..HEAD~2")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(r.stdout.splitlines()), 2)
        self.assertEqual(self.worktrees(), [str(self.repo)])

    def test_empty_and_bad_range(self):
        r = self.each(self.CHECK, "HEAD..HEAD")
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "no commits in HEAD..HEAD"))
        self.assertEqual(self.each(self.CHECK, "nope..nada").returncode, 2)

    def test_sigterm_cleans_up(self):
        p = subprocess.Popen([str(EACH)], cwd=self.repo, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             env=dict(self.env, PREFLIGHT_EACH_CMD="sleep 30"))
        p.stdout.readline()  # the header: the worktree exists by now
        self.assertEqual(len(self.worktrees()), 2)
        t0 = time.time()
        p.send_signal(signal.SIGTERM)
        p.communicate(timeout=10)
        self.assertLess(time.time() - t0, 10)
        self.assertEqual(p.returncode, 130)
        self.assertEqual(self.worktrees(), [str(self.repo)])


if __name__ == "__main__":
    unittest.main(verbosity=1)
