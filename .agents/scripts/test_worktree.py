#!/usr/bin/env python3
"""Offline fixtures for worktree.py (new, prune), preflight-each.py and
preflight-brief.py, in throwaway repos with a bare `origin` and a fake
`gh` (prints nothing: no PR recorded) on PATH. prune is checked for what
it removes AND what it must leave: dirty, unlanded, pushed-but-empty,
too-fresh, outside the root, the main checkout. preflight-each runs a
stand-in check (PREFLIGHT_EACH_CMD) and must leave no worktree behind, on
success, failure, SIGTERM, and SIGINT (to it, or its whole process
group, with and without --jobs), must kill a job's whole group (members
that ignore TERM or outlive the leader), must take its jobs down when
SIGKILLed (PR_SET_PDEATHSIG), and its sweep must remove only worktrees it
marked itself for a dead run on this host and boot -- never an unmarked,
mismatched, nested or main checkout, whatever its name. It also must keep
commit order under --jobs, clamp --jobs by memory (cgroup included; 1
when unreadable), and cache only passing checks by flake tree.
preflight-brief runs a fixture repo's own `preflight` recipe: order,
tails, fail-fast, the serial-last step, the cached check, TEST_JOBS
split, a step that can't start, repeated signals. Stdlib (plus `just`
for preflight-brief); runs in `just preflight`.
"""
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
WT = HERE / "worktree.py"
EACH = HERE / "preflight-each.py"
BRIEF = HERE / "preflight-brief.py"
GIT_ENV = dict(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
               GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")


def _proc_start(pid):
    """/proc start time of a live, non-zombie pid, else None."""
    try:
        st = Path(f"/proc/{pid}/stat").read_text()
    except OSError:
        return None
    fields = st[st.rindex(")") + 2:].split()
    return None if fields[0] == "Z" else int(fields[19])


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
        result = self.run_("new", branch, "--root", str(self.root), *more)
        self.assertEqual(result.returncode, 0, result.stderr)
        return Path(result.stdout.strip())

    def worktrees(self):
        return [line[9:] for line in git(self.repo, "worktree", "list",
                                   "--porcelain").splitlines()
                if line.startswith("worktree ")]

    def branches(self):
        return git(self.repo, "branch", "--format=%(refname:short)").split()


class New(Base):
    def test_creates_and_prints_only_the_path(self):
        result = self.run_("new", "feat/a-b", "--root", str(self.root))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, f"{self.root / 'wt-a-b'}\n")
        worktree_path = self.root / "wt-a-b"
        self.assertEqual(git(worktree_path, "branch", "--show-current"), "feat/a-b")
        self.assertEqual(git(worktree_path, "rev-parse", "HEAD"),
                         git(self.repo, "rev-parse", "origin/experimental"))

    def test_env_root_and_base(self):
        commit(self.repo, "local-only")  # local experimental ahead of origin
        env = dict(self.env, AGENT_SCRATCH=str(self.root))
        result = self.run_("new", "plain", "experimental", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        worktree_path = self.root / "wt-plain"
        self.assertEqual(result.stdout.strip(), str(worktree_path))
        self.assertEqual(git(worktree_path, "rev-parse", "HEAD"),
                         git(self.repo, "rev-parse", "experimental"))

    def test_refuses_existing_branch_path_or_remote(self):
        self.new("feat/a")
        result = self.run_("new", "feat/a", "--root", str(self.root))
        self.assertEqual(result.returncode, 1)
        self.assertIn("refs/heads/feat/a already exists", result.stderr)
        result = self.run_("new", "fix/a", "--root", str(self.root))  # same dir
        self.assertEqual(result.returncode, 1)
        self.assertIn("wt-a already exists", result.stderr)
        self.assertNotIn("fix/a", self.branches())
        git(self.repo, "push", "-q", "origin", "experimental:refs/heads/feat/r")
        result = self.run_("new", "feat/r", "--root", str(self.root))
        self.assertEqual(result.returncode, 1)
        self.assertIn("refs/remotes/origin/feat/r already exists", result.stderr)


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
        return next(out_line for out_line in out.splitlines() if f"  {path}  " in out_line)

    def test_dry_run_reports_and_removes_nothing(self):
        before = self.worktrees()
        result = self.prune()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.worktrees(), before)
        out = result.stdout
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
        result = self.prune("--yes")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        left = set(self.worktrees())
        for worktree_path in (self.landed, self.fresh, self.detached):
            self.assertNotIn(str(worktree_path), left)
            self.assertFalse(worktree_path.exists())
        for worktree_path in (self.open_, self.dirty, self.pushed, self.outside, self.repo):
            self.assertIn(str(worktree_path), left)
        branch_names = self.branches()
        self.assertNotIn("feat/landed", branch_names)
        self.assertNotIn("feat/fresh", branch_names)
        for kept in ("feat/open", "feat/dirty", "feat/pushed", "feat/outside"):
            self.assertIn(kept, branch_names)
        self.assertEqual((self.dirty / "base").read_text(), "changed\n")

    def test_never_removes_a_protected_branch(self):
        # a clean worktree on main/master/experimental that otherwise reads
        # as fresh or landed must keep its worktree AND its branch
        for name in ("main", "master"):
            worktree_path = self.root / f"wt-prot-{name}"
            git(self.repo, "worktree", "add", "-q", str(worktree_path), "-b", name,
                "origin/experimental")
            result = self.prune("--yes")
            self.assertTrue(self.line(result.stdout, worktree_path).startswith("keep"), result.stdout)
            self.assertIn("protected", self.line(result.stdout, worktree_path))
            self.assertTrue(worktree_path.exists())
            self.assertIn(name, self.branches())

    def test_min_age_protects_a_new_worktree(self):
        result = self.run_("prune", "--root", str(self.root), "--yes")  # default 60m
        self.assertIn("touched 0m ago", self.line(result.stdout, self.fresh))
        self.assertTrue(self.fresh.exists())
        self.assertFalse(self.landed.exists())

    def test_never_removes_the_worktree_it_runs_in(self):
        result = self.run_("prune", "--root", str(self.root), "--min-age", "0",
                      "--yes", cwd=self.fresh)
        self.assertIn("the worktree this runs in", result.stdout)
        self.assertTrue(self.fresh.exists())


class PreflightEach(Base):
    CHECK = ('if [ -e bad ]; then echo "FAIL  step"; echo boom; exit 1; fi;'
             ' echo "preflight passed: 3 steps"')

    def setUp(self):
        super().setUp()
        # Plenty of memory unless a test says otherwise: --jobs must not be
        # clamped by whatever the host running the tests has free.
        (self.t / "meminfo").write_text("MemAvailable: 1073741824 kB\n")
        self.env["PREFLIGHT_EACH_MEMINFO"] = str(self.t / "meminfo")
        # No cgroup limit unless a test sets one.
        self.env["PREFLIGHT_EACH_PROC_CGROUP"] = str(self.t / "no-such-cgroup")
        self.setup_tmpdir()
        git(self.repo, "switch", "-qc", "feat/e")
        commit(self.repo, "one", msg="feat: one")
        commit(self.repo, "bad", msg="feat: breaks it")
        git(self.repo, "rm", "-q", "bad")
        git(self.repo, "commit", "-qm", "fix: unbreak")

    def each(self, check, *args):
        return self.run_(*args, script=EACH,
                         env=dict(self.env, PREFLIGHT_EACH_CMD=check))

    def test_one_line_per_commit_and_failure_tail(self):
        result = self.each(self.CHECK)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        lines = result.stdout.splitlines()
        self.assertIn("3 commits in origin/experimental..HEAD", lines[0])
        self.assertRegex(lines[1], r"^ok   [0-9a-f]{8} feat: one  \(3 steps, \d+s\)$")
        self.assertRegex(lines[2], r"^FAIL [0-9a-f]{8} feat: breaks it")
        self.assertIn("     boom", lines)
        self.assertRegex(lines[-1], r"^ok   [0-9a-f]{8} fix: unbreak")
        self.assertEqual(self.worktrees(), [str(self.repo)])

    def test_all_green_and_range(self):
        result = self.each(self.CHECK, "HEAD~3..HEAD~2")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), 2)
        self.assertEqual(self.worktrees(), [str(self.repo)])

    def test_empty_and_bad_range(self):
        result = self.each(self.CHECK, "HEAD..HEAD")
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "no commits in HEAD..HEAD"))
        self.assertEqual(self.each(self.CHECK, "nope..nada").returncode, 2)

    def interrupt(self, sig, *args, group=False, jobs=1):
        """Start a run whose check sleeps, signal it once its worktrees
        exist (to the pid, or the whole process group as a terminal's ^C
        does), and assert it exits 130 promptly with none left."""
        before = self.worktrees()
        proc = subprocess.Popen([str(EACH), *args], cwd=self.repo, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             env=dict(self.env, PREFLIGHT_EACH_CMD="sleep 30"),
                             start_new_session=group)
        proc.stdout.readline()  # the header: the worktrees exist by now
        self.assertEqual(len(self.worktrees()), len(before) + jobs)
        time.sleep(0.3)      # let the checks start
        t0 = time.time()
        if group:
            os.killpg(proc.pid, sig)
        else:
            proc.send_signal(sig)
        _, err = proc.communicate(timeout=15)
        self.assertLess(time.time() - t0, 15)
        self.assertEqual(proc.returncode, 130, err)
        self.assertIn("interrupted", err)
        self.assertEqual(self.worktrees(), before)
        self.assertEqual(list(self.t.glob("tmp/preflight-each.*")), [])

    def setup_tmpdir(self):
        (self.t / "tmp").mkdir(exist_ok=True)
        self.env["TMPDIR"] = str(self.t / "tmp")

    def test_sigterm_cleans_up(self):
        self.setup_tmpdir()
        self.interrupt(signal.SIGTERM)

    def test_sigint_cleans_up(self):
        self.setup_tmpdir()
        self.interrupt(signal.SIGINT)

    def test_sigint_to_process_group_cleans_up(self):
        self.setup_tmpdir()
        self.interrupt(signal.SIGINT, group=True)

    def test_sighup_with_jobs_cleans_up(self):
        self.setup_tmpdir()
        self.interrupt(signal.SIGHUP, "--jobs", "2", group=True, jobs=2)

    def test_check_that_ignores_sigterm_is_killed_before_cleanup(self):
        self.setup_tmpdir()
        pidfile = self.t / "pid"
        proc = subprocess.Popen(
            [str(EACH)], cwd=self.repo, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=dict(self.env, PREFLIGHT_EACH_CMD=(
                f"trap '' TERM INT HUP; echo $$ > {pidfile}; exec sleep 30")))
        proc.stdout.readline()
        while not pidfile.exists() or not pidfile.read_text().strip():
            time.sleep(0.05)
        pid = int(pidfile.read_text())
        proc.send_signal(signal.SIGINT)
        proc.communicate(timeout=20)
        self.assertEqual(proc.returncode, 130)
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)
        self.assertEqual(self.worktrees(), [str(self.repo)])

    # -- the stale-worktree sweep ------------------------------------------
    def dead_pid(self):
        proc = subprocess.Popen(["true"])
        proc.wait()
        return proc.pid

    def marked(self, name, pid, host=None, boot=None, start=123, repo=None):
        """A worktree marked as preflight-each's own: locked with its
        reason, and the marker file in its admin dir."""
        repo = repo or self.repo
        host = host or socket.gethostname()
        boot = boot or Path("/proc/sys/kernel/random/boot_id").read_text().strip()
        path = self.t / "tmp" / name
        reason = f"preflight-each:{host}:{boot}:{pid}:{start}"
        git(repo, "worktree", "add", "-q", "--detach", "--lock", "--reason",
            reason, str(path), "HEAD")
        admin = Path(git(path, "rev-parse", "--path-format=absolute", "--git-dir"))
        (admin / "preflight-each.json").write_text(json.dumps(
            {"host": host, "boot": boot, "pid": pid, "start": start,
             "path": str(path), "pgids": []}))
        return path

    def test_sweeps_only_marked_dead_runs_of_this_boot(self):
        dead = self.dead_pid()
        stale = self.marked(f"preflight-each.{dead}.abc", dead)
        other_boot = self.marked(f"preflight-each.{dead}.boot", dead, boot="other-boot")
        other_host = self.marked(f"preflight-each.{dead}.host", dead, host="elsewhere")
        alive = self.marked(f"preflight-each.{os.getpid()}.live", os.getpid(),
                            start=_proc_start(os.getpid()))
        result = self.each(self.CHECK, "HEAD~1..HEAD")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("removed 1 worktree(s) left by a killed run", result.stderr)
        self.assertFalse(stale.exists())
        for kept in (other_boot, other_host, alive):
            self.assertTrue(kept.exists())
            self.assertIn(str(kept), self.worktrees())

    def test_sweep_ignores_unmarked_and_mismatched_worktrees(self):
        dead = self.dead_pid()
        tmp = self.t / "tmp"
        # A user worktree with a matching name, dirty, no lock or marker.
        user = tmp / f"preflight-each.{dead}.user"
        git(self.repo, "worktree", "add", "-q", "--detach", str(user), "HEAD")
        (user / "base").write_text("user's edit\n")
        # Locked with the right reason but no marker file.
        lonely = tmp / f"preflight-each.{dead}.nomarker"
        boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
        git(self.repo, "worktree", "add", "-q", "--detach", "--lock", "--reason",
            f"preflight-each:{socket.gethostname()}:{boot}:{dead}:1",
            str(lonely), "HEAD")
        # A marked one outside the temp dir.
        deeper = tmp / "sub"
        deeper.mkdir()
        nested = self.marked(f"sub/preflight-each.{dead}.nested", dead)
        # Huge numbers in the name and the reason: skipped, no crash.
        huge = self.marked("preflight-each.9999999999.huge", 10**30)
        result = self.each(self.CHECK, "HEAD~1..HEAD")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertNotIn("removed", result.stderr)
        for kept in (user, lonely, nested, huge):
            self.assertIn(str(kept), self.worktrees())
        self.assertEqual((user / "base").read_text(), "user's edit\n")

    def test_sweep_never_touches_the_main_checkout(self):
        # The checkout preflight-each runs from is itself named like one of
        # its worktrees, sits in its temp dir, and carries a dead run's
        # marker in .git/: still never swept.
        dead = self.dead_pid()
        main = self.t / "tmp" / f"preflight-each.{dead}.repo"
        subprocess.run(["git", "clone", "-q", str(self.origin), str(main)],
                       check=True, env=self.env)
        git(main, "switch", "-qc", "feat/m")
        commit(main, "m")
        boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
        (main / ".git" / "preflight-each.json").write_text(json.dumps(
            {"host": socket.gethostname(), "boot": boot, "pid": dead,
             "start": 1, "path": str(main), "pgids": []}))
        result = self.run_(cwd=main, script=EACH,
                      env=dict(self.env, PREFLIGHT_EACH_CMD=self.CHECK))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((main / "m").exists())
        self.assertNotIn("removed", result.stderr)

    def test_sigkilled_run_takes_its_jobs_down_and_is_swept_next_time(self):
        pidfile = self.t / "pid"
        proc = subprocess.Popen(
            [str(EACH)], cwd=self.repo, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=dict(self.env, PREFLIGHT_EACH_CMD=f"echo $$ > {pidfile}; exec sleep 30"))
        proc.stdout.readline()
        while not pidfile.exists() or not pidfile.read_text().strip():
            time.sleep(0.05)
        job = int(pidfile.read_text())
        proc.kill()
        proc.communicate(timeout=10)
        deadline = time.time() + 5   # PR_SET_PDEATHSIG: the kernel TERMs it
        while time.time() < deadline and _proc_start(job) is not None:
            time.sleep(0.05)
        self.assertIsNone(_proc_start(job))
        self.assertEqual(len(self.worktrees()), 2)   # left behind, marked
        result = self.each(self.CHECK, "HEAD~1..HEAD")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("removed 1 worktree(s) left by a killed run", result.stderr)
        self.assertEqual(self.worktrees(), [str(self.repo)])
        self.assertEqual(list((self.t / "tmp").glob("preflight-each.*")), [])

    def test_job_member_outliving_its_leader_is_killed(self):
        pidfile = self.t / "member"
        result = self.each(f"sh -c 'trap \"\" TERM; exec sleep 30' & echo $! > {pidfile}; "
                      + self.CHECK, "HEAD~1..HEAD")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIsNone(_proc_start(int(pidfile.read_text())))
        self.assertEqual(self.worktrees(), [str(self.repo)])

    def test_jobs_keep_commit_order(self):
        # The first commit is the slowest, so with 3 jobs it finishes last;
        # its line must still print first.
        slow = 'if [ -e bad ] || [ -e one ]; then :; else sleep 1; fi; ' + self.CHECK
        result = self.each(slow, "--jobs", "3")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        heads = [out_line for out_line in result.stdout.splitlines() if not out_line.startswith("     ")]
        self.assertIn("(3 worktrees)", heads[0])
        self.assertRegex(heads[1], r"^ok   [0-9a-f]{8} feat: one ")
        self.assertRegex(heads[2], r"^FAIL [0-9a-f]{8} feat: breaks it")
        self.assertRegex(heads[3], r"^ok   [0-9a-f]{8} fix: unbreak")
        self.assertIn("     boom", result.stdout.splitlines())
        self.assertEqual(self.worktrees(), [str(self.repo)])

    def test_jobs_clamped_by_memory(self):
        meminfo = self.t / "meminfo"
        meminfo.write_text("MemTotal: 99 kB\nMemAvailable: 7340032 kB\n")  # 7 GiB
        env = dict(self.env, PREFLIGHT_EACH_CMD=self.CHECK,
                   PREFLIGHT_EACH_MEMINFO=str(meminfo))
        # No flake/ here, so every commit counts as its own tree: 2 jobs
        # need 2 checks + 2 rests, more than 7 GiB; 1 job fits.
        result = self.run_("--jobs", "2", script=EACH, env=env)
        self.assertIn("--jobs 2 reduced to 1: MemAvailable 7.0 GiB", result.stderr)
        self.assertIn("(worktree ", result.stdout.splitlines()[0])
        meminfo.write_text("MemAvailable: 1024 kB\n")  # never below one job
        result = self.run_("--jobs", "3", script=EACH, env=env)
        self.assertIn("reduced to 1", result.stderr)
        self.assertEqual(result.returncode, 1)  # still ran, still found `bad`
        self.assertEqual(self.run_("--jobs", "0", script=EACH, env=env).returncode, 2)

    def test_jobs_capped_when_meminfo_unreadable_or_malformed(self):
        for text in (None, "MemAvailable: lots kB\n", "MemTotal: 5 kB\n"):
            with self.subTest(text=text):
                meminfo = self.t / "meminfo2"
                meminfo.unlink(missing_ok=True)
                if text is not None:
                    meminfo.write_text(text)
                result = self.run_("--jobs", "3", script=EACH, env=dict(
                    self.env, PREFLIGHT_EACH_CMD=self.CHECK,
                    PREFLIGHT_EACH_MEMINFO=str(meminfo)))
                self.assertIn("--jobs 3 reduced to 1: can't read MemAvailable", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
                self.assertIn("(worktree ", result.stdout.splitlines()[0])

    def test_jobs_clamped_by_cgroup_headroom(self):
        root = self.t / "cg"
        (root / "a" / "b").mkdir(parents=True)
        (root / "a" / "memory.max").write_text(f"{8 * 2**30}\n")
        (root / "a" / "memory.current").write_text(f"{1 * 2**30}\n")
        (root / "a" / "b" / "memory.max").write_text("max\n")
        (self.t / "proc-cgroup").write_text("0::/a/b\n")
        env = dict(self.env, PREFLIGHT_EACH_CMD=self.CHECK,
                   PREFLIGHT_EACH_CGROUP_ROOT=str(root),
                   PREFLIGHT_EACH_PROC_CGROUP=str(self.t / "proc-cgroup"))
        result = self.run_("--jobs", "3", script=EACH, env=env)
        self.assertIn("reduced to 1: cgroup memory.max headroom 7.0 GiB", result.stderr)
        (root / "a" / "memory.max").write_text(f"{100 * 2**30}\n")
        result = self.run_("--jobs", "3", script=EACH, env=env)
        self.assertNotIn("reduced", result.stderr)
        self.assertIn("(3 worktrees)", result.stdout.splitlines()[0])

    def test_check_cached_by_flake_tree(self):
        # flake tree A, then a doc-only commit (still A), then B, whose
        # check fails, then a doc-only commit on B: a failure is never
        # cached, so that commit runs the check again.
        git(self.repo, "switch", "-qc", "feat/cache", "origin/experimental")
        (self.repo / "flake").mkdir()
        commit(self.repo, "flake/a.nix", msg="flake: A")
        commit(self.repo, "doc1", msg="doc: one")
        commit(self.repo, "flake/b.nix", msg="flake: B")
        commit(self.repo, "doc2", msg="doc: two")
        ran = self.t / "ran"
        check = (f'sha=$(git rev-parse --short=8 HEAD); '
                 f'if [ -n "$PREFLIGHT_CACHED_CHECK" ]; then '
                 f'  echo "$sha cached $PREFLIGHT_CACHED_CHECK" >> {ran}; '
                 f'else '
                 f'  echo "$sha ran" >> {ran}; '
                 f'  v=ok; [ -e flake/b.nix ] && v=fail; '
                 f'  echo "{{\\"just check\\": \\"$v\\"}}" > "$PREFLIGHT_STATUS_FILE"; '
                 f'fi; echo "preflight passed: 1 steps"')
        for jobs in ("1", "4"):
            with self.subTest(jobs=jobs):
                ran.unlink(missing_ok=True)
                result = self.each(check, "--jobs", jobs)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                shas = git(self.repo, "rev-list", "--reverse",
                           "origin/experimental..HEAD").split()
                short_shas = [sha[:8] for sha in shas]
                self.assertEqual(sorted(ran.read_text().splitlines()), sorted([
                    f"{short_shas[0]} ran", f"{short_shas[1]} cached {short_shas[0]}",
                    f"{short_shas[2]} ran", f"{short_shas[3]} ran"]))
                self.assertEqual(self.worktrees(), [str(self.repo)])


class PreflightBrief(Base):
    """preflight-brief against a fixture repo's own `preflight` recipe."""

    def setUp(self):
        super().setUp()
        if shutil.which("just") is None:
            self.skipTest("just not on PATH")

    def brief(self, steps, recipes="", env=None):
        (self.repo / ".justfile").write_text(
            "preflight:\n    # a comment line, not a step\n"
            + "".join(f"    @{step}\n" for step in steps) + "\n" + recipes)
        return subprocess.run([str(BRIEF)], cwd=self.repo, text=True,
                              capture_output=True,
                              env=dict(self.env, **(env or {})))

    def test_green_in_recipe_order_with_notes(self):
        result = self.brief(["sleep 0.5; echo REVIEW a; echo REVIEW b",
                        "echo 'NOTE: hello'", "echo fast"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        lines = result.stdout.splitlines()
        self.assertRegex(lines[0], r"^ok    sleep 0\.5.*\s+\d+s  \(2 REVIEW notes\)$")
        self.assertRegex(lines[1], r"^ok    echo 'NOTE: hello'")
        self.assertEqual(lines[2], "      NOTE: hello")
        self.assertRegex(lines[3], r"^ok    echo fast")
        self.assertRegex(lines[4], r"^preflight passed: 3 steps in \d+s$")

    def test_failure_tail_stops_the_rest_and_skips_lint(self):
        t0 = time.time()
        result = self.brief(["echo ok-one",
                        "sleep 30",
                        "sleep 1; for i in $(seq 1 40); do echo line$i; done; exit 3",
                        "just lint"],
                       recipes="lint:\n    @touch linted\n")
        self.assertLess(time.time() - t0, 15)   # sleep 30 was stopped
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        out = result.stdout.splitlines()
        self.assertRegex(out[0], r"^ok    echo ok-one")
        self.assertRegex(out[1], r"^stop  sleep 30 .*\(stopped: sleep 1; for i in")
        self.assertRegex(out[2], r"^FAIL  sleep 1; for i in")
        self.assertIn("line40", out)
        self.assertIn("line11", out)        # the last 30 lines
        self.assertNotIn("line10", out)
        self.assertRegex(result.stdout, r"skip  just lint .*\(not run: sleep 1; for i in")
        self.assertRegex(out[-1], r"^preflight FAILED: 1 of 4 steps")
        self.assertFalse((self.repo / "linted").exists())

    def test_lint_runs_after_the_others(self):
        result = self.brief(["sleep 0.5; touch first", "just lint"],
                       recipes="lint:\n    @test -e first\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_cached_check(self):
        recipes = "check:\n    @touch checked\n"
        status = self.t / "status.json"
        result = self.brief(["just check", "echo x"], recipes,
                       env={"PREFLIGHT_CACHED_CHECK": "abcd1234",
                            "PREFLIGHT_STATUS_FILE": str(status)})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertRegex(result.stdout, r"ok    just check .*\(cached: same flake tree as abcd1234\)")
        self.assertFalse((self.repo / "checked").exists())
        self.assertEqual(json.loads(status.read_text()),
                         {"just check": "cached", "echo x": "ok"})
        result = self.brief(["just check"], recipes,
                       env={"PREFLIGHT_STATUS_FILE": str(status)})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.repo / "checked").exists())
        self.assertEqual(json.loads(status.read_text()), {"just check": "ok"})

    def test_test_jobs_split_across_concurrent_suites(self):
        result = self.brief(["echo \"NOTE: a-test $TEST_JOBS\"",
                        "echo \"NOTE: b-test $TEST_JOBS\"", "true"],
                       env={"TEST_JOBS": "8"})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("      NOTE: a-test 4", result.stdout.splitlines())
        result = self.brief(["echo \"NOTE: test $TEST_JOBS\""] * 1 + ["echo test2"] * 7,
                       env={"TEST_JOBS": "8"})
        self.assertIn("      NOTE: test 2", result.stdout.splitlines())   # floor of 2

    def test_step_that_cannot_start_fails_without_hanging(self):
        # PATH holds what preflight-brief itself needs, but no bash.
        bin_ = self.t / "nobash"
        bin_.mkdir()
        for tool in ("just", "git", "python3", "env"):
            (bin_ / tool).symlink_to(shutil.which(tool))
        (self.repo / ".justfile").write_text("preflight:\n    @echo hi\n")
        result = subprocess.run(["python3", str(BRIEF)], cwd=self.repo, text=True,
                           capture_output=True, timeout=30,
                           env=dict(self.env, PATH=str(bin_)))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertRegex(result.stdout, r"FAIL  echo hi")
        self.assertIn("could not start", result.stdout)

    def test_repeated_signals_stop_every_step_once(self):
        (self.repo / ".justfile").write_text(
            "preflight:\n    @sleep 30\n    @sleep 31\n")
        proc = subprocess.Popen([str(BRIEF)], cwd=self.repo, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             env=self.env)
        time.sleep(1.0)
        for _ in range(3):
            proc.send_signal(signal.SIGTERM)
            proc.send_signal(signal.SIGINT)
        _, err = proc.communicate(timeout=20)
        self.assertEqual(proc.returncode, 130, err)
        self.assertEqual(err.count("interrupted"), 1)

    def test_step_member_outliving_its_leader_is_killed(self):
        pidfile = self.t / "member"
        result = self.brief([f"sh -c 'trap \"\" TERM; exec sleep 30' & echo $! > {pidfile}"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIsNone(_proc_start(int(pidfile.read_text())))


if __name__ == "__main__":
    # flake/scripts/parallel_unittest.py: same tests, across processes
    sys.path.insert(0, str(HERE.parents[1] / "flake" / "scripts"))
    import parallel_unittest
    parallel_unittest.main()
