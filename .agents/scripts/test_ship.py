#!/usr/bin/env python3
"""Offline fixtures for ship.py: the gate and land flow against a fake `gh`
(and a fake `just`, for close-fixed) on PATH, in throwaway git repos with a
bare `origin`; commit's pathspec, branch refusal and trailer handling in a
temp repo. Nothing here talks to GitHub. The fake gh answers from a JSON
state file and, on `pr merge`, does what GitHub would: pushes the PR head
onto origin's experimental and (delete_branch_on_merge) deletes the remote
branch. Stdlib only.
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SHIP = HERE / "ship.py"
sys.path.insert(0, str(HERE))
import ship  # noqa: E402

FAKE_GH = r'''#!/usr/bin/env python3
import json, os, subprocess, sys
st_path = os.environ["FAKE_STATE"]
st = json.load(open(st_path))
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write("gh " + " ".join(sys.argv[1:]) + "\n")
a = sys.argv[1:]
pr = st["pr"]
if a[:2] == ["pr", "checks"]:
    sys.exit(st.get("checks_rc", 0))
if a[:2] == ["pr", "view"]:
    if "-q" in a:
        print(pr["state"]); sys.exit(0)
    seq = st.get("status_seq")
    if seq:
        pr["mergeStateStatus"] = seq.pop(0)
        json.dump(st, open(st_path, "w"))
    print(json.dumps(pr)); sys.exit(0)
if a[:2] in (["pr", "create"], ["pr", "edit"]):
    print("https://example/pull/8"); sys.exit(st.get("create_rc", 0))
if a[:2] == ["pr", "merge"]:
    if st.get("merge_rc"):
        print("merge refused", file=sys.stderr); sys.exit(st["merge_rc"])
    git = ["git", "-C", st["origin"]]
    subprocess.run(git + ["update-ref", "refs/heads/experimental", pr["headRefOid"]], check=True)
    subprocess.run(git + ["update-ref", "-d", "refs/heads/" + pr["headRefName"]], check=True)
    pr["state"] = "MERGED"
    json.dump(st, open(st_path, "w")); sys.exit(0)
sys.exit("fake gh: unhandled " + " ".join(a))
'''

FAKE_JUST = '''#!/bin/sh
echo "just $*" >> "$FAKE_LOG"
'''


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def commit(cwd, name, text="x\n"):
    (Path(cwd) / name).write_text(text)
    git(cwd, "add", name)
    git(cwd, "commit", "-qm", f"add {name}")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.t = Path(self.tmp.name)
        bin_ = self.t / "bin"
        bin_.mkdir()
        (bin_ / "gh").write_text(FAKE_GH)
        (bin_ / "just").write_text(FAKE_JUST)
        for f in bin_.iterdir():
            f.chmod(0o755)
        self.log = self.t / "log"
        self.log.write_text("")
        self.state = self.t / "state.json"
        self.env = dict(os.environ, PATH=f"{bin_}:{os.environ['PATH']}",
                        FAKE_LOG=str(self.log), FAKE_STATE=str(self.state),
                        SHIP_RETRY_SECONDS="0", GIT_CONFIG_GLOBAL="/dev/null",
                        GIT_CONFIG_NOSYSTEM="1", GIT_AUTHOR_NAME="t",
                        GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
                        GIT_COMMITTER_EMAIL="t@t")
        os.environ.update({k: self.env[k] for k in
                           ("GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM",
                            "GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL",
                            "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL")})
        # origin (bare) with experimental; a clone with a pushed feature branch
        self.origin = self.t / "origin.git"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "experimental",
                        str(self.origin)], check=True)
        self.repo = self.t / "repo"
        subprocess.run(["git", "init", "-q", "-b", "experimental",
                        str(self.repo)], check=True)
        commit(self.repo, "base")
        git(self.repo, "remote", "add", "origin", str(self.origin))
        git(self.repo, "push", "-qu", "origin", "experimental")

    def tearDown(self):
        self.tmp.cleanup()

    def feature(self, cwd, n=1, name="feat/x"):
        git(cwd, "switch", "-qc", name, "origin/experimental")
        for i in range(n):
            commit(cwd, f"f{i}")
        git(cwd, "push", "-qu", "origin", name)
        return git(cwd, "rev-parse", "HEAD")

    def pr(self, head, oid, n=1, **over):
        d = dict(url="https://example/pull/7", title="feat: x", state="OPEN",
                 isDraft=False, additions=3, deletions=1, changedFiles=1,
                 mergeable="MERGEABLE", mergeStateStatus="CLEAN",
                 baseRefName="experimental", headRefName=head, headRefOid=oid,
                 commits=[dict(oid=f"{i:040d}", messageHeadline=f"c{i}")
                          for i in range(n)])
        d.update(over)
        return d

    def set_state(self, pr, **extra):
        self.state.write_text(json.dumps(dict(pr=pr, origin=str(self.origin),
                                              **extra)))

    def ship(self, *args, cwd=None, stdin=None):
        return subprocess.run([sys.executable, str(SHIP), *args],
                              cwd=cwd or self.repo, env=self.env, text=True,
                              input=stdin, capture_output=True)

    def calls(self):
        return self.log.read_text().splitlines()

    def branches(self, cwd=None):
        return git(cwd or self.repo, "branch", "--format=%(refname:short)").split()

    def remote_has(self, name):
        return subprocess.run(["git", "-C", str(self.origin), "rev-parse", "-q",
                               "--verify", f"refs/heads/{name}"],
                              capture_output=True).returncode == 0


class Gate(unittest.TestCase):
    def d(self, **over):
        d = dict(state="OPEN", isDraft=False, mergeStateStatus="CLEAN",
                 mergeable="MERGEABLE", baseRefName="experimental",
                 commits=[{}])
        d.update(over)
        return d

    def test_clean_passes(self):
        self.assertEqual(ship.gate_problems(self.d()), [])

    def test_mergeable_is_not_ci(self):
        # #413: MERGEABLE with red CI read as mergeable.
        p = ship.gate_problems(self.d(mergeStateStatus="BLOCKED"))
        self.assertEqual(len(p), 1)
        self.assertIn("BLOCKED", p[0])
        self.assertIn("only means no conflicts", p[0])

    def test_base_main_refused(self):
        p = ship.gate_problems(self.d(baseRefName="main"))
        self.assertIn("not experimental", p[0])

    def test_not_open_is_the_only_problem(self):
        p = ship.gate_problems(self.d(state="MERGED", mergeStateStatus="UNKNOWN"))
        self.assertEqual(p, ["state is MERGED, not OPEN"])

    def test_draft(self):
        self.assertTrue(ship.gate_problems(self.d(isDraft=True)))

    def test_method(self):
        self.assertEqual(ship.method(self.d(commits=[{}])), "--rebase")
        self.assertEqual(ship.method(self.d(commits=[{}, {}])), "--merge")


class Ready(Base):
    def test_ready(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid))
        r = self.ship("ready", "7")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("merge method: --rebase", r.stdout)
        self.assertIn("READY", r.stdout)
        self.assertIn("gh pr checks 7 --watch --interval 20", self.calls())

    def test_red_checks_not_ready(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid), checks_rc=1)
        r = self.ship("ready", "7")
        self.assertEqual(r.returncode, 1)
        self.assertIn("NOT READY", r.stdout)
        self.assertIn("gh pr checks exited 1", r.stdout)

    def test_unknown_is_reread(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid, mergeStateStatus="UNKNOWN"),
                       status_seq=["UNKNOWN", "UNKNOWN", "CLEAN"])
        r = self.ship("ready", "7")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertEqual(sum("pr view" in c for c in self.calls()), 3)


class Land(Base):
    def test_single_checkout(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid))
        r = self.ship("land", "7")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"gh pr merge 7 --rebase --match-head-commit {oid}",
                      self.calls())
        self.assertNotIn("--delete-branch", self.log.read_text())
        self.assertEqual(git(self.repo, "branch", "--show-current"), "experimental")
        self.assertEqual(git(self.repo, "rev-parse", "HEAD"), oid)  # pulled
        self.assertNotIn("feat/x", self.branches())
        self.assertIn("just close-fixed 7", self.calls())

    def test_multi_commit_merges_and_deletes_leftover_remote(self):
        oid = self.feature(self.repo, n=2)
        self.set_state(self.pr("feat/x", oid, n=2))
        # A merge that left the remote branch behind: land deletes it.
        fake = self.t / "bin" / "gh"
        fake.write_text(FAKE_GH.replace(
            'subprocess.run(git + ["update-ref", "-d"', 'None and subprocess.run(git + ["update-ref", "-d"'))
        r = self.ship("land", "7")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue(any(c.startswith("gh pr merge 7 --merge") for c in self.calls()))
        self.assertFalse(self.remote_has("feat/x"))

    KEEP_REMOTE = ('subprocess.run(git + ["update-ref", "-d"',
                   'None and subprocess.run(git + ["update-ref", "-d"')

    def racing_delete(self, really_delete):
        """origin's pre-receive hook: a branch delete fails; with
        really_delete the ref is gone anyway -- GitHub's delete-on-merge
        winning the race between ls-remote and the push."""
        hook = self.origin / "hooks" / "pre-receive"
        rm = 'rm -f "refs/heads/${ref#refs/heads/}"' if really_delete else ":"
        hook.write_text("#!/bin/sh\nwhile read old new ref; do\n"
                        '  case $new in 0000000000000000000000000000000000000000)'
                        f" {rm}; exit 1;; esac\ndone\n")
        hook.chmod(0o755)

    def test_remote_delete_race_is_done(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid))
        (self.t / "bin" / "gh").write_text(FAKE_GH.replace(*self.KEEP_REMOTE))
        self.racing_delete(really_delete=True)
        r = self.ship("land", "7")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("goal already holds", r.stdout)
        self.assertFalse(self.remote_has("feat/x"))
        self.assertIn("just close-fixed 7", self.calls())

    def test_remote_delete_failure_still_fails(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid))
        (self.t / "bin" / "gh").write_text(FAKE_GH.replace(*self.KEEP_REMOTE))
        self.racing_delete(really_delete=False)
        r = self.ship("land", "7")
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("FAILED: git push origin --delete feat/x", r.stdout)
        self.assertTrue(self.remote_has("feat/x"))
        self.assertNotIn("just close-fixed 7", self.calls())

    def test_rebased_merge_with_pruned_tracking_ref(self):
        # GitHub's rebase merge gives new SHAs; with origin/<branch> pruned,
        # plain `branch -d` would refuse. The tip equals the merged PR head,
        # so -D is safe and used.
        oid = self.feature(self.repo)
        git(self.repo, "config", "fetch.prune", "true")
        rebased = git(self.origin, "commit-tree", "-p",
                      git(self.origin, "rev-parse", "experimental"),
                      "-m", "rebased", git(self.repo, "rev-parse", "HEAD^{tree}"))
        self.set_state(self.pr("feat/x", rebased))
        # the PR head on GitHub is `oid`; the merge lands `rebased`
        st = json.loads(self.state.read_text())
        st["pr"]["headRefOid"] = oid
        self.state.write_text(json.dumps(st))
        (self.t / "bin" / "gh").write_text(FAKE_GH.replace(
            'pr["headRefOid"]], check=True)', f'"{rebased}"], check=True)'))
        r = self.ship("land", "7")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("git branch -D feat/x", r.stdout)
        self.assertNotIn("feat/x", self.branches())

    def test_linked_worktree(self):
        # experimental is checked out in the shared checkout; the agent is in
        # a linked worktree on the PR branch. The shared checkout must not
        # move; the linked one detaches; the branch goes.
        wt = self.t / "wt"
        git(self.repo, "worktree", "add", "-q", str(wt), "-b", "feat/x",
            "origin/experimental")
        commit(wt, "f0")
        git(wt, "push", "-qu", "origin", "feat/x")
        oid = git(wt, "rev-parse", "HEAD")
        before = git(self.repo, "rev-parse", "HEAD")
        self.set_state(self.pr("feat/x", oid))
        r = self.ship("land", "7", cwd=wt)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("not pulled there", r.stdout)
        self.assertEqual(git(self.repo, "rev-parse", "HEAD"), before)
        self.assertEqual(git(self.repo, "branch", "--show-current"), "experimental")
        self.assertEqual(git(wt, "branch", "--show-current"), "")  # detached
        self.assertEqual(git(wt, "rev-parse", "HEAD"), oid)
        self.assertNotIn("feat/x", self.branches())
        self.assertIn("just close-fixed 7", self.calls())

    def test_branch_held_by_another_worktree_is_left(self):
        oid = self.feature(self.repo)
        git(self.repo, "switch", "-q", "experimental")
        other = self.t / "other"
        git(self.repo, "worktree", "add", "-q", str(other), "feat/x")
        here = self.t / "here"
        git(self.repo, "worktree", "add", "-q", "--detach", str(here))
        self.set_state(self.pr("feat/x", oid))
        r = self.ship("land", "7", cwd=here)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"git worktree remove {other}", r.stdout)
        self.assertIn("feat/x", self.branches())

    def test_gate_refusal_merges_nothing(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid, mergeStateStatus="BLOCKED"))
        r = self.ship("land", "7")
        self.assertEqual(r.returncode, 1)
        self.assertIn("refusing", r.stdout)
        self.assertFalse(any("pr merge" in c for c in self.calls()))

    def test_base_main_refused(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid, baseRefName="main"))
        self.assertEqual(self.ship("land", "7").returncode, 1)
        self.assertFalse(any("pr merge" in c for c in self.calls()))

    def test_failed_merge_deletes_nothing(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid), merge_rc=1)
        r = self.ship("land", "7")
        self.assertEqual(r.returncode, 1)
        self.assertIn("nothing deleted", r.stdout)
        self.assertIn("feat/x", self.branches())
        self.assertTrue(self.remote_has("feat/x"))
        self.assertNotIn("just close-fixed 7", self.calls())

    def test_failed_step_stops_and_lists_rest(self):
        oid = self.feature(self.repo)
        git(self.repo, "switch", "-q", "experimental")
        git(self.repo, "branch", "--unset-upstream")  # pull --ff-only fails
        git(self.repo, "switch", "-q", "feat/x")
        self.set_state(self.pr("feat/x", oid))
        r = self.ship("land", "7")
        self.assertEqual(r.returncode, 1)
        self.assertIn("FAILED: git pull --ff-only", r.stdout)
        self.assertIn("feat/x", self.branches())
        self.assertNotIn("just close-fixed 7", self.calls())


class Pr(Base):
    GOOD = ("🤖 Generated by an LLM agent\n\n## What changed\n\nx\n\n"
            "## Why\n\ny\n\n🤖 Generated with [Claude Code](https://x)\n")

    def body(self, text=None):
        f = self.t / "body.md"
        f.write_text(self.GOOD if text is None else text)
        return str(f)

    def local_feature(self, n=1):
        git(self.repo, "switch", "-qc", "feat/p", "origin/experimental")
        for i in range(n):
            commit(self.repo, f"p{i}")

    def creates(self):
        return [c for c in self.calls() if c.startswith("gh pr create")]

    def test_pushes_and_opens(self):
        self.set_state({})
        self.local_feature()
        r = self.ship("pr", self.body())
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue(self.remote_has("feat/p"))
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "@{u}"),
                         "origin/feat/p")
        self.assertEqual(self.creates(), [
            "gh pr create --base experimental --head feat/p --title add p0"
            f" --body-file {self.t / 'body.md'}"])

    def test_several_commits_need_title(self):
        self.set_state({})
        self.local_feature(n=2)
        r = self.ship("pr", self.body())
        self.assertEqual(r.returncode, 1)
        self.assertIn("pass --title", r.stderr)
        self.assertEqual(self.creates(), [])
        r = self.ship("pr", self.body(), "--title", "feat: two")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("--title feat: two", self.creates()[0])

    def test_protected_branch_refused(self):
        self.set_state({})
        r = self.ship("pr", self.body())  # on experimental
        self.assertEqual(r.returncode, 1)
        self.assertIn("refusing on experimental", r.stderr)
        self.assertEqual(self.creates(), [])

    def test_disclosure_required_top_and_bottom(self):
        self.set_state({})
        self.local_feature()
        no_top = self.GOOD.split("\n", 2)[2]
        no_bottom = self.GOOD.rsplit("🤖", 1)[0]
        # the template's own comment mentions the line; it doesn't count
        in_comment = "<!-- 🤖 Generated by an LLM agent -->\n" + no_top
        for text in (no_top, no_bottom, in_comment):
            r = self.ship("pr", self.body(text))
            self.assertEqual(r.returncode, 1, text)
            self.assertIn("lacks the LLM disclosure", r.stdout)
        self.assertEqual(self.creates(), [])
        self.assertFalse(self.remote_has("feat/p"))  # nothing pushed either

    def test_edit(self):
        self.set_state({})
        r = self.ship("pr", self.body(), "--edit", "12")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.calls(), [
            f"gh pr edit 12 --body-file {self.t / 'body.md'}"])


class Commit(Base):
    MSG = "feat: a thing\n\nBody with `backticks` and $(not run).\n"

    def setUp(self):
        super().setUp()
        git(self.repo, "switch", "-qc", "feat/c")
        (self.repo / "a").write_text("a\n")
        (self.repo / "b").write_text("b\n")
        git(self.repo, "add", "a", "b")

    def last(self):
        return git(self.repo, "log", "-1", "--format=%B")

    def committed(self):
        return git(self.repo, "show", "--name-only", "--format=", "HEAD").split()

    def test_trailer_appended_and_pathspec_honoured(self):
        r = self.ship("commit", "--", "a", stdin=self.MSG)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.committed(), ["a"])  # b stays staged, uncommitted
        self.assertIn("b", git(self.repo, "diff", "--cached", "--name-only"))
        body = self.last()
        self.assertIn("`backticks` and $(not run)", body)
        self.assertTrue(body.endswith("\n\nCo-Authored-By: Claude"), body)

    def test_agent_flag(self):
        r = self.ship("commit", "--agent", "ZCode", "a", stdin=self.MSG)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(self.last().endswith("Co-Authored-By: ZCode"))

    def test_existing_trailer_kept(self):
        msg = self.MSG + "\nCo-authored-by: opencode\n"
        r = self.ship("commit", "a", stdin=msg)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.last().lower().count("co-authored-by"), 1)
        self.assertNotIn("warning", r.stderr)

    def test_model_email_trailer_warns(self):
        msg = self.MSG + "\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n"
        r = self.ship("commit", "a", stdin=msg)
        self.assertEqual(r.returncode, 0)
        self.assertIn("warning", r.stderr)

    def test_joins_existing_trailer_block(self):
        msg = "fix: y\n\nwhy.\n\nFixes: #12\n"
        self.assertEqual(ship.with_trailer(msg, "Claude"),
                         "fix: y\n\nwhy.\n\nFixes: #12\nCo-Authored-By: Claude\n")
        self.assertEqual(ship.with_trailer("docs: z\n", "Claude"),
                         "docs: z\n\nCo-Authored-By: Claude\n")

    def test_no_paths_refused(self):
        r = self.ship("commit", stdin=self.MSG)
        self.assertEqual(r.returncode, 1)
        self.assertIn("at least one path", r.stderr)
        r = self.ship("commit", "--", stdin=self.MSG)
        self.assertEqual(r.returncode, 1)

    def test_empty_message_refused(self):
        r = self.ship("commit", "a", stdin="  \n")
        self.assertEqual(r.returncode, 1)
        self.assertIn("empty", r.stderr)

    def test_protected_branches_refused(self):
        for b in ("experimental", "main"):
            git(self.repo, "switch", "-qC", b)
            r = self.ship("commit", "a", stdin=self.MSG)
            self.assertEqual(r.returncode, 1, b)
            self.assertIn(f"refusing to commit on {b}", r.stderr)

    def _commit_only(self, *paths):
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t",
            "commit", "-qm", "setup", "--", *paths)

    def test_symlink_replaced_by_directory_refused(self):
        os.symlink("a", self.repo / "l")
        git(self.repo, "add", "l")
        self._commit_only("l")
        head = git(self.repo, "rev-parse", "HEAD")
        (self.repo / "l").unlink()
        (self.repo / "l").mkdir()
        (self.repo / "l" / "f").write_text("x\n")
        r = self.ship("commit", "--", "l", stdin=self.MSG)
        self.assertEqual(r.returncode, 1)
        self.assertIn("changed type", r.stderr)
        self.assertEqual(git(self.repo, "rev-parse", "HEAD"), head)
        self.assertIn("b", git(self.repo, "diff", "--cached", "--name-only"))

    def test_trailing_slash_on_ordinary_directory_commits(self):
        (self.repo / "d").mkdir()
        (self.repo / "d" / "f").write_text("x\n")
        git(self.repo, "add", "d")
        self._commit_only("d")
        (self.repo / "d" / "f").write_text("y\n")
        r = self.ship("commit", "--", "d/", stdin=self.MSG)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.committed(), ["d/f"])

    def test_directory_replaced_by_symlink_refused(self):
        (self.repo / "d").mkdir()
        (self.repo / "d" / "f").write_text("x\n")
        git(self.repo, "add", "d")
        self._commit_only("d")
        (self.repo / "d" / "f").unlink()
        (self.repo / "d").rmdir()
        os.symlink("a", self.repo / "d")
        r = self.ship("commit", "--", "d", stdin=self.MSG)
        self.assertEqual(r.returncode, 1)
        self.assertIn("changed type", r.stderr)

    def test_detached_head_refused(self):
        # ship-land leaves a linked worktree detached; a commit there would
        # belong to no branch.
        git(self.repo, "switch", "-q", "--detach")
        r = self.ship("commit", "a", stdin=self.MSG)
        self.assertEqual(r.returncode, 1)
        self.assertIn("detached HEAD", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=1)
