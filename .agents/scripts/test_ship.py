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
        for file_handle in bin_.iterdir():
            file_handle.chmod(0o755)
        self.log = self.t / "log"
        self.log.write_text("")
        self.state = self.t / "state.json"
        self.env = dict(os.environ, PATH=f"{bin_}:{os.environ['PATH']}",
                        FAKE_LOG=str(self.log), FAKE_STATE=str(self.state),
                        SHIP_RETRY_SECONDS="0", GIT_CONFIG_GLOBAL="/dev/null",
                        GIT_CONFIG_NOSYSTEM="1", GIT_AUTHOR_NAME="t",
                        GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
                        GIT_COMMITTER_EMAIL="t@t")
        os.environ.update({name: self.env[name] for name in
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

    def feature(self, cwd, commit_count=1, name="feat/x"):
        git(cwd, "switch", "-qc", name, "origin/experimental")
        for index in range(commit_count):
            commit(cwd, f"f{index}")
        git(cwd, "push", "-qu", "origin", name)
        return git(cwd, "rev-parse", "HEAD")

    def pr(self, head, oid, commit_count=1, **over):
        pr_data = dict(url="https://example/pull/7", title="feat: x", state="OPEN",
                 isDraft=False, additions=3, deletions=1, changedFiles=1,
                 mergeable="MERGEABLE", mergeStateStatus="CLEAN",
                 baseRefName="experimental", headRefName=head, headRefOid=oid,
                 isCrossRepository=False,
                 commits=[dict(oid=f"{index:040d}", messageHeadline=f"c{index}")
                          for index in range(commit_count)])
        pr_data.update(over)
        return pr_data

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
    def gate_data(self, **over):
        pr_data = dict(state="OPEN", isDraft=False, mergeStateStatus="CLEAN",
                 mergeable="MERGEABLE", baseRefName="experimental",
                 headRefName="feat/x", isCrossRepository=False, commits=[{}])
        pr_data.update(over)
        return pr_data

    def test_clean_passes(self):
        self.assertEqual(ship.gate_problems(self.gate_data()), [])

    def test_mergeable_is_not_ci(self):
        # #413: MERGEABLE with red CI read as mergeable.
        problems = ship.gate_problems(self.gate_data(mergeStateStatus="BLOCKED"))
        self.assertEqual(len(problems), 1)
        self.assertIn("BLOCKED", problems[0])
        self.assertIn("only means no conflicts", problems[0])

    def test_base_main_refused(self):
        problems = ship.gate_problems(self.gate_data(baseRefName="main"))
        self.assertIn("not experimental", problems[0])

    def test_fork_head_refused(self):
        problems = ship.gate_problems(self.gate_data(isCrossRepository=True))
        self.assertTrue(any("another repository" in problem for problem in problems), problems)

    def test_unknown_origin_counts_as_fork(self):
        pr_data = self.gate_data()
        del pr_data["isCrossRepository"]
        self.assertTrue(any("another repository" in problem
                            for problem in ship.gate_problems(pr_data)))

    def test_protected_head_refused(self):
        for name in ("main", "master", "experimental"):
            problems = ship.gate_problems(self.gate_data(headRefName=name))
            self.assertTrue(any("protected" in problem or "same as the base" in problem
                                for problem in problems), (name, problems))

    def test_not_open_is_the_only_problem(self):
        problems = ship.gate_problems(self.gate_data(state="MERGED", mergeStateStatus="UNKNOWN"))
        self.assertEqual(problems, ["state is MERGED, not OPEN"])

    def test_draft(self):
        self.assertTrue(ship.gate_problems(self.gate_data(isDraft=True)))

    def test_method(self):
        self.assertEqual(ship.method(self.gate_data(commits=[{}])), "--rebase")
        self.assertEqual(ship.method(self.gate_data(commits=[{}, {}])), "--merge")


class Ready(Base):
    def test_ready(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid))
        result = self.ship("ready", "7")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("merge method: --rebase", result.stdout)
        self.assertIn("READY", result.stdout)
        self.assertIn("gh pr checks 7 --watch --interval 20", self.calls())

    def test_red_checks_not_ready(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid), checks_rc=1)
        result = self.ship("ready", "7")
        self.assertEqual(result.returncode, 1)
        self.assertIn("NOT READY", result.stdout)
        self.assertIn("gh pr checks exited 1", result.stdout)

    def test_unknown_is_reread(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid, mergeStateStatus="UNKNOWN"),
                       status_seq=["UNKNOWN", "UNKNOWN", "CLEAN"])
        result = self.ship("ready", "7")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(sum("pr view" in call for call in self.calls()), 3)


class Land(Base):
    def test_single_checkout(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid))
        result = self.ship("land", "7")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"gh pr merge 7 --rebase --match-head-commit {oid}",
                      self.calls())
        self.assertNotIn("--delete-branch", self.log.read_text())
        self.assertEqual(git(self.repo, "branch", "--show-current"), "experimental")
        self.assertEqual(git(self.repo, "rev-parse", "HEAD"), oid)  # pulled
        self.assertNotIn("feat/x", self.branches())
        self.assertIn("just close-fixed 7", self.calls())

    def test_multi_commit_merges_and_deletes_leftover_remote(self):
        oid = self.feature(self.repo, commit_count=2)
        self.set_state(self.pr("feat/x", oid, commit_count=2))
        # A merge that left the remote branch behind: land deletes it.
        fake = self.t / "bin" / "gh"
        fake.write_text(FAKE_GH.replace(
            'subprocess.run(git + ["update-ref", "-d"', 'None and subprocess.run(git + ["update-ref", "-d"'))
        result = self.ship("land", "7")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(any(call.startswith("gh pr merge 7 --merge") for call in self.calls()))
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
        result = self.ship("land", "7")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("goal already holds", result.stdout)
        self.assertFalse(self.remote_has("feat/x"))
        self.assertIn("just close-fixed 7", self.calls())

    def test_remote_delete_failure_still_fails(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid))
        (self.t / "bin" / "gh").write_text(FAKE_GH.replace(*self.KEEP_REMOTE))
        self.racing_delete(really_delete=False)
        result = self.ship("land", "7")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("FAILED: git push origin --delete feat/x", result.stdout)
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
        result = self.ship("land", "7")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("git branch -D feat/x", result.stdout)
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
        result = self.ship("land", "7", cwd=wt)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("not pulled there", result.stdout)
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
        result = self.ship("land", "7", cwd=here)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"git worktree remove {other}", result.stdout)
        self.assertIn("feat/x", self.branches())

    def test_gate_refusal_merges_nothing(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid, mergeStateStatus="BLOCKED"))
        result = self.ship("land", "7")
        self.assertEqual(result.returncode, 1)
        self.assertIn("refusing", result.stdout)
        self.assertFalse(any("pr merge" in call for call in self.calls()))

    def test_base_main_refused(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid, baseRefName="main"))
        self.assertEqual(self.ship("land", "7").returncode, 1)
        self.assertFalse(any("pr merge" in call for call in self.calls()))

    def test_fork_or_protected_head_merges_and_deletes_nothing(self):
        # a head named like a protected branch must never reach the delete
        for index, over in enumerate((dict(headRefName="main"),
                                  dict(headRefName="experimental"),
                                  dict(isCrossRepository=True))):
            with self.subTest(over=over):
                self.log.write_text("")
                oid = self.feature(self.repo, name=f"feat/x{index}")
                self.set_state(self.pr("feat/x", oid, **over))
                result = self.ship("land", "7")
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                joined = "\n".join(self.calls())
                self.assertNotIn("pr merge", joined)
                self.assertNotIn("--delete", joined)
                git(self.repo, "switch", "-q", "experimental")

    def test_local_branch_at_another_tip_is_not_force_deleted(self):
        oid = self.feature(self.repo)
        git(self.repo, "switch", "-q", "experimental")
        # local branch has an extra commit the merged PR head lacks
        git(self.repo, "switch", "-q", "feat/x")
        commit(self.repo, "extra")
        git(self.repo, "switch", "-q", "experimental")
        self.set_state(self.pr("feat/x", oid))
        self.ship("land", "7")
        self.assertIn("feat/x", self.branches())  # never -D'd

    def test_failed_merge_deletes_nothing(self):
        oid = self.feature(self.repo)
        self.set_state(self.pr("feat/x", oid), merge_rc=1)
        result = self.ship("land", "7")
        self.assertEqual(result.returncode, 1)
        self.assertIn("nothing deleted", result.stdout)
        self.assertIn("feat/x", self.branches())
        self.assertTrue(self.remote_has("feat/x"))
        self.assertNotIn("just close-fixed 7", self.calls())

    def test_failed_step_stops_and_lists_rest(self):
        oid = self.feature(self.repo)
        git(self.repo, "switch", "-q", "experimental")
        git(self.repo, "branch", "--unset-upstream")  # pull --ff-only fails
        git(self.repo, "switch", "-q", "feat/x")
        self.set_state(self.pr("feat/x", oid))
        result = self.ship("land", "7")
        self.assertEqual(result.returncode, 1)
        self.assertIn("FAILED: git pull --ff-only", result.stdout)
        self.assertIn("feat/x", self.branches())
        self.assertNotIn("just close-fixed 7", self.calls())


class Pr(Base):
    GOOD = ("🤖 Co-written by an LLM agent\n\n## What changed\n\nx\n\n"
            "## Why\n\ny\n")

    def body(self, text=None):
        file_handle = self.t / "body.md"
        file_handle.write_text(self.GOOD if text is None else text)
        return str(file_handle)

    def local_feature(self, commit_count=1):
        git(self.repo, "switch", "-qc", "feat/p", "origin/experimental")
        for index in range(commit_count):
            commit(self.repo, f"p{index}")

    def creates(self):
        return [call for call in self.calls() if call.startswith("gh pr create")]

    def test_pushes_and_opens(self):
        self.set_state({})
        self.local_feature()
        result = self.ship("pr", self.body())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.remote_has("feat/p"))
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "@{u}"),
                         "origin/feat/p")
        self.assertEqual(self.creates(), [
            "gh pr create --base experimental --head feat/p --title add p0"
            f" --body-file {self.t / 'body.md'}"])

    def test_several_commits_need_title(self):
        self.set_state({})
        self.local_feature(commit_count=2)
        result = self.ship("pr", self.body())
        self.assertEqual(result.returncode, 1)
        self.assertIn("pass --title", result.stderr)
        self.assertEqual(self.creates(), [])
        result = self.ship("pr", self.body(), "--title", "feat: two")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("--title feat: two", self.creates()[0])

    def test_protected_branch_refused(self):
        self.set_state({})
        result = self.ship("pr", self.body())  # on experimental
        self.assertEqual(result.returncode, 1)
        self.assertIn("refusing on experimental", result.stderr)
        self.assertEqual(self.creates(), [])

    def test_disclosure_required_at_top(self):
        self.set_state({})
        self.local_feature()
        no_top = self.GOOD.split("\n", 2)[2]
        # the template's own comment mentions the line; it doesn't count
        in_comment = "<!-- 🤖 Co-written by an LLM agent -->\n" + no_top
        for text in (no_top, in_comment):
            result = self.ship("pr", self.body(text))
            self.assertEqual(result.returncode, 1, text)
            self.assertIn("lacks the LLM disclosure", result.stdout)
        self.assertEqual(self.creates(), [])
        self.assertFalse(self.remote_has("feat/p"))  # nothing pushed either

    def test_edit(self):
        self.set_state({})
        result = self.ship("pr", self.body(), "--edit", "12")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
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
        result = self.ship("commit", "--", "a", stdin=self.MSG)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.committed(), ["a"])  # b stays staged, uncommitted
        self.assertIn("b", git(self.repo, "diff", "--cached", "--name-only"))
        body = self.last()
        self.assertIn("`backticks` and $(not run)", body)
        self.assertTrue(body.endswith("\n\nCo-Authored-By: Claude"), body)

    def test_agent_flag(self):
        result = self.ship("commit", "--agent", "ZCode", "a", stdin=self.MSG)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.last().endswith("Co-Authored-By: ZCode"))

    def test_existing_trailer_kept(self):
        msg = self.MSG + "\nCo-authored-by: opencode\n"
        result = self.ship("commit", "a", stdin=msg)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.last().lower().count("co-authored-by"), 1)
        self.assertNotIn("warning", result.stderr)

    def test_model_email_trailer_warns(self):
        msg = self.MSG + "\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n"
        result = self.ship("commit", "a", stdin=msg)
        self.assertEqual(result.returncode, 0)
        self.assertIn("warning", result.stderr)

    def test_joins_existing_trailer_block(self):
        msg = "fix: y\n\nwhy.\n\nFixes: #12\n"
        self.assertEqual(ship.with_trailer(msg, "Claude"),
                         "fix: y\n\nwhy.\n\nFixes: #12\nCo-Authored-By: Claude\n")
        self.assertEqual(ship.with_trailer("docs: z\n", "Claude"),
                         "docs: z\n\nCo-Authored-By: Claude\n")

    def test_no_paths_refused(self):
        result = self.ship("commit", stdin=self.MSG)
        self.assertEqual(result.returncode, 1)
        self.assertIn("at least one path", result.stderr)
        result = self.ship("commit", "--", stdin=self.MSG)
        self.assertEqual(result.returncode, 1)

    def test_empty_message_refused(self):
        result = self.ship("commit", "a", stdin="  \n")
        self.assertEqual(result.returncode, 1)
        self.assertIn("empty", result.stderr)

    def test_protected_branches_refused(self):
        for branch_name in ("experimental", "main"):
            git(self.repo, "switch", "-qC", branch_name)
            result = self.ship("commit", "a", stdin=self.MSG)
            self.assertEqual(result.returncode, 1, branch_name)
            self.assertIn(f"refusing to commit on {branch_name}", result.stderr)

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
        result = self.ship("commit", "--", "l", stdin=self.MSG)
        self.assertEqual(result.returncode, 1)
        self.assertIn("changed type", result.stderr)
        self.assertEqual(git(self.repo, "rev-parse", "HEAD"), head)
        self.assertIn("b", git(self.repo, "diff", "--cached", "--name-only"))

    def test_trailing_slash_on_ordinary_directory_commits(self):
        (self.repo / "d").mkdir()
        (self.repo / "d" / "f").write_text("x\n")
        git(self.repo, "add", "d")
        self._commit_only("d")
        (self.repo / "d" / "f").write_text("y\n")
        result = self.ship("commit", "--", "d/", stdin=self.MSG)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.committed(), ["d/f"])

    def test_directory_replaced_by_symlink_refused(self):
        (self.repo / "d").mkdir()
        (self.repo / "d" / "f").write_text("x\n")
        git(self.repo, "add", "d")
        self._commit_only("d")
        (self.repo / "d" / "f").unlink()
        (self.repo / "d").rmdir()
        os.symlink("a", self.repo / "d")
        result = self.ship("commit", "--", "d", stdin=self.MSG)
        self.assertEqual(result.returncode, 1)
        self.assertIn("changed type", result.stderr)

    def test_detached_head_refused(self):
        # ship-land leaves a linked worktree detached; a commit there would
        # belong to no branch.
        git(self.repo, "switch", "-q", "--detach")
        result = self.ship("commit", "a", stdin=self.MSG)
        self.assertEqual(result.returncode, 1)
        self.assertIn("detached HEAD", result.stderr)


if __name__ == "__main__":
    # flake/scripts/parallel_unittest.py: same tests, across processes
    sys.path.insert(0, str(HERE.parents[1] / "flake" / "scripts"))
    import parallel_unittest
    parallel_unittest.main()
