#!/usr/bin/env python3
"""Offline fixtures for where.py: a temp repo with a bare `origin`, and a
fake `gh` on PATH answering from a JSON state file (a PR, "no pull
requests found", or a failure). Checks what it reports, that it tolerates
an unreachable origin and a missing gh, and that it changes nothing.
Nothing here talks to GitHub. Stdlib only.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

WHERE = Path(__file__).resolve().parent / "where.py"

FAKE_GH = r'''#!/usr/bin/env python3
import json, os, sys
st = json.load(open(os.environ["FAKE_STATE"]))
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write("gh " + " ".join(sys.argv[1:]) + "\n")
if sys.argv[1:3] != ["pr", "view"]:
    sys.exit("fake gh: unhandled")
if st.get("err"):
    print(st["err"], file=sys.stderr); sys.exit(1)
print(json.dumps(st["pr"]))
'''


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def commit(cwd, name, text="x\n"):
    (Path(cwd) / name).write_text(text)
    git(cwd, "add", name)
    git(cwd, "commit", "-qm", f"add {name}")


class Where(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.t = Path(self.tmp.name)
        self.bin = self.t / "bin"
        self.bin.mkdir()
        (self.bin / "gh").write_text(FAKE_GH)
        (self.bin / "gh").chmod(0o755)
        self.log = self.t / "log"
        self.log.write_text("")
        self.state = self.t / "state.json"
        self.set_state(err="no pull requests found for branch \"feat/x\"")
        gitenv = dict(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
                      GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
                      GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        FAKE_LOG=str(self.log), FAKE_STATE=str(self.state),
                        **gitenv)
        os.environ.update(gitenv)
        self.origin = self.t / "origin.git"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "experimental",
                        str(self.origin)], check=True)
        self.repo = self.t / "repo"
        subprocess.run(["git", "init", "-q", "-b", "experimental",
                        str(self.repo)], check=True)
        commit(self.repo, "base")
        git(self.repo, "remote", "add", "origin", str(self.origin))
        git(self.repo, "push", "-qu", "origin", "experimental")
        git(self.repo, "switch", "-qc", "feat/x", "origin/experimental")
        commit(self.repo, "one")
        commit(self.repo, "two", "a\nb\n")

    def tearDown(self):
        self.tmp.cleanup()

    def set_state(self, **st):
        self.state.write_text(json.dumps(st))

    def where(self, *args, env=None):
        p = subprocess.run([sys.executable, str(WHERE), *args], cwd=self.repo,
                           env=env or self.env, text=True, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p.stdout

    def snapshot(self):
        """Everything where.py must leave alone (remote-tracking refs are
        fetch's to move, so they are excluded)."""
        return (git(self.repo, "rev-parse", "HEAD"),
                git(self.repo, "branch", "--show-current"),
                git(self.repo, "for-each-ref", "refs/heads", "refs/tags"),
                git(self.repo, "status", "--porcelain"),
                git(self.repo, "stash", "list"),
                git(self.repo, "worktree", "list"))

    def test_reports_branch_dirty_commits_stat_and_no_pr(self):
        (self.repo / "base").write_text("changed\n")
        (self.repo / "new.txt").write_text("n\n")
        before = self.snapshot()
        out = self.where()
        self.assertEqual(before, self.snapshot())
        self.assertIn("fetch: origin ok", out)
        self.assertIn("## feat/x", out)
        self.assertIn("dirty: 2 paths", out)
        self.assertIn(" M base", out)
        self.assertIn("vs origin/experimental: ahead 2, behind 0", out)
        self.assertIn("add one", out)
        self.assertIn("add two", out)
        self.assertIn("2 files changed, 3 insertions(+)", out)
        self.assertIn("PR: none for feat/x", out)
        self.assertIn("gh pr view --json number,title,state,mergeStateStatus,url",
                      self.log.read_text())

    def test_behind_after_another_landing(self):
        other = self.t / "other"
        subprocess.run(["git", "clone", "-q", str(self.origin), str(other)],
                       check=True)
        commit(other, "landed")
        git(other, "push", "-q", "origin", "experimental")
        out = self.where()
        self.assertIn("ahead 2, behind 1", out)   # the fetch saw it

    def test_branch_pr_and_explicit_pr(self):
        pr = dict(number=7, title="feat: x", state="OPEN",
                  mergeStateStatus="CLEAN", url="https://example/pull/7",
                  headRefName="feat/x", baseRefName="experimental")
        self.set_state(pr=pr)
        out = self.where()
        self.assertIn("PR: #7 OPEN CLEAN experimental <- feat/x", out)
        self.assertIn("https://example/pull/7", out)
        self.where("12")
        self.assertIn("gh pr view 12 --json", self.log.read_text())

    def test_offline_continues_on_cached_refs(self):
        git(self.repo, "remote", "set-url", "origin", str(self.t / "gone.git"))
        self.set_state(err="error connecting to api.github.com")
        out = self.where()
        self.assertIn("fetch: FAILED", out)
        self.assertIn("continuing with cached refs", out)
        self.assertIn("ahead 2, behind 0", out)
        self.assertIn("PR: lookup failed (error connecting", out)

    def test_no_gh_on_path(self):
        bare = self.t / "bare-bin"
        bare.mkdir()
        (bare / "git").symlink_to(shutil.which("git"))
        out = self.where(env=dict(self.env, PATH=str(bare)))
        self.assertIn("PR: gh not on PATH", out)
        self.assertIn("ahead 2", out)

    def test_trunk_and_detached_skip_the_lookup(self):
        git(self.repo, "switch", "-q", "experimental")
        self.assertIn("PR: none looked up (on experimental)", self.where())
        git(self.repo, "switch", "-q", "--detach", "feat/x")
        self.assertIn("PR: none looked up (detached HEAD)", self.where())
        self.assertEqual(self.log.read_text(), "")

    def test_outside_a_repo_and_bad_usage(self):
        d = self.t / "plain"
        d.mkdir()
        p = subprocess.run([sys.executable, str(WHERE)], cwd=d, env=self.env,
                           text=True, capture_output=True)
        self.assertEqual(p.returncode, 2)
        p = subprocess.run([sys.executable, str(WHERE), "1", "2"],
                           cwd=self.repo, env=self.env, text=True,
                           capture_output=True)
        self.assertEqual(p.returncode, 2)


if __name__ == "__main__":
    unittest.main()
