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

    def interrupt(self, sig, *args, group=False, jobs=1):
        """Start a run whose check sleeps, signal it once its worktrees
        exist (to the pid, or the whole process group as a terminal's ^C
        does), and assert it exits 130 promptly with none left."""
        before = self.worktrees()
        p = subprocess.Popen([str(EACH), *args], cwd=self.repo, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             env=dict(self.env, PREFLIGHT_EACH_CMD="sleep 30"),
                             start_new_session=group)
        p.stdout.readline()  # the header: the worktrees exist by now
        self.assertEqual(len(self.worktrees()), len(before) + jobs)
        time.sleep(0.3)      # let the checks start
        t0 = time.time()
        if group:
            os.killpg(p.pid, sig)
        else:
            p.send_signal(sig)
        _, err = p.communicate(timeout=15)
        self.assertLess(time.time() - t0, 15)
        self.assertEqual(p.returncode, 130, err)
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
        p = subprocess.Popen(
            [str(EACH)], cwd=self.repo, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=dict(self.env, PREFLIGHT_EACH_CMD=(
                f"trap '' TERM INT HUP; echo $$ > {pidfile}; exec sleep 30")))
        p.stdout.readline()
        while not pidfile.exists() or not pidfile.read_text().strip():
            time.sleep(0.05)
        pid = int(pidfile.read_text())
        p.send_signal(signal.SIGINT)
        p.communicate(timeout=20)
        self.assertEqual(p.returncode, 130)
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)
        self.assertEqual(self.worktrees(), [str(self.repo)])

    # -- the stale-worktree sweep ------------------------------------------
    def dead_pid(self):
        p = subprocess.Popen(["true"])
        p.wait()
        return p.pid

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
        r = self.each(self.CHECK, "HEAD~1..HEAD")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("removed 1 worktree(s) left by a killed run", r.stderr)
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
        r = self.each(self.CHECK, "HEAD~1..HEAD")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn("Traceback", r.stderr)
        self.assertNotIn("removed", r.stderr)
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
        r = self.run_(cwd=main, script=EACH,
                      env=dict(self.env, PREFLIGHT_EACH_CMD=self.CHECK))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((main / "m").exists())
        self.assertNotIn("removed", r.stderr)

    def test_sigkilled_run_takes_its_jobs_down_and_is_swept_next_time(self):
        pidfile = self.t / "pid"
        p = subprocess.Popen(
            [str(EACH)], cwd=self.repo, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=dict(self.env, PREFLIGHT_EACH_CMD=f"echo $$ > {pidfile}; exec sleep 30"))
        p.stdout.readline()
        while not pidfile.exists() or not pidfile.read_text().strip():
            time.sleep(0.05)
        job = int(pidfile.read_text())
        p.kill()
        p.communicate(timeout=10)
        deadline = time.time() + 5   # PR_SET_PDEATHSIG: the kernel TERMs it
        while time.time() < deadline and _proc_start(job) is not None:
            time.sleep(0.05)
        self.assertIsNone(_proc_start(job))
        self.assertEqual(len(self.worktrees()), 2)   # left behind, marked
        r = self.each(self.CHECK, "HEAD~1..HEAD")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("removed 1 worktree(s) left by a killed run", r.stderr)
        self.assertEqual(self.worktrees(), [str(self.repo)])
        self.assertEqual(list((self.t / "tmp").glob("preflight-each.*")), [])

    def test_job_member_outliving_its_leader_is_killed(self):
        pidfile = self.t / "member"
        r = self.each(f"sh -c 'trap \"\" TERM; exec sleep 30' & echo $! > {pidfile}; "
                      + self.CHECK, "HEAD~1..HEAD")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIsNone(_proc_start(int(pidfile.read_text())))
        self.assertEqual(self.worktrees(), [str(self.repo)])

    def test_jobs_keep_commit_order(self):
        # The first commit is the slowest, so with 3 jobs it finishes last;
        # its line must still print first.
        slow = 'if [ -e bad ] || [ -e one ]; then :; else sleep 1; fi; ' + self.CHECK
        r = self.each(slow, "--jobs", "3")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        heads = [l for l in r.stdout.splitlines() if not l.startswith("     ")]
        self.assertIn("(3 worktrees)", heads[0])
        self.assertRegex(heads[1], r"^ok   [0-9a-f]{8} feat: one ")
        self.assertRegex(heads[2], r"^FAIL [0-9a-f]{8} feat: breaks it")
        self.assertRegex(heads[3], r"^ok   [0-9a-f]{8} fix: unbreak")
        self.assertIn("     boom", r.stdout.splitlines())
        self.assertEqual(self.worktrees(), [str(self.repo)])

    def test_jobs_clamped_by_memory(self):
        meminfo = self.t / "meminfo"
        meminfo.write_text("MemTotal: 99 kB\nMemAvailable: 7340032 kB\n")  # 7 GiB
        env = dict(self.env, PREFLIGHT_EACH_CMD=self.CHECK,
                   PREFLIGHT_EACH_MEMINFO=str(meminfo))
        # No flake/ here, so every commit counts as its own tree: 2 jobs
        # need 2 checks + 2 rests, more than 7 GiB; 1 job fits.
        r = self.run_("--jobs", "2", script=EACH, env=env)
        self.assertIn("--jobs 2 reduced to 1: MemAvailable 7.0 GiB", r.stderr)
        self.assertIn("(worktree ", r.stdout.splitlines()[0])
        meminfo.write_text("MemAvailable: 1024 kB\n")  # never below one job
        r = self.run_("--jobs", "3", script=EACH, env=env)
        self.assertIn("reduced to 1", r.stderr)
        self.assertEqual(r.returncode, 1)  # still ran, still found `bad`
        self.assertEqual(self.run_("--jobs", "0", script=EACH, env=env).returncode, 2)

    def test_jobs_capped_when_meminfo_unreadable_or_malformed(self):
        for text in (None, "MemAvailable: lots kB\n", "MemTotal: 5 kB\n"):
            with self.subTest(text=text):
                meminfo = self.t / "meminfo2"
                meminfo.unlink(missing_ok=True)
                if text is not None:
                    meminfo.write_text(text)
                r = self.run_("--jobs", "3", script=EACH, env=dict(
                    self.env, PREFLIGHT_EACH_CMD=self.CHECK,
                    PREFLIGHT_EACH_MEMINFO=str(meminfo)))
                self.assertIn("--jobs 3 reduced to 1: can't read MemAvailable", r.stderr)
                self.assertNotIn("Traceback", r.stderr)
                self.assertIn("(worktree ", r.stdout.splitlines()[0])

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
        r = self.run_("--jobs", "3", script=EACH, env=env)
        self.assertIn("reduced to 1: cgroup memory.max headroom 7.0 GiB", r.stderr)
        (root / "a" / "memory.max").write_text(f"{100 * 2**30}\n")
        r = self.run_("--jobs", "3", script=EACH, env=env)
        self.assertNotIn("reduced", r.stderr)
        self.assertIn("(3 worktrees)", r.stdout.splitlines()[0])

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
                r = self.each(check, "--jobs", jobs)
                self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
                shas = git(self.repo, "rev-list", "--reverse",
                           "origin/experimental..HEAD").split()
                s = [x[:8] for x in shas]
                self.assertEqual(sorted(ran.read_text().splitlines()), sorted([
                    f"{s[0]} ran", f"{s[1]} cached {s[0]}",
                    f"{s[2]} ran", f"{s[3]} ran"]))
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
            + "".join(f"    @{s}\n" for s in steps) + "\n" + recipes)
        return subprocess.run([str(BRIEF)], cwd=self.repo, text=True,
                              capture_output=True,
                              env=dict(self.env, **(env or {})))

    def test_green_in_recipe_order_with_notes(self):
        r = self.brief(["sleep 0.5; echo REVIEW a; echo REVIEW b",
                        "echo 'NOTE: hello'", "echo fast"])
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        lines = r.stdout.splitlines()
        self.assertRegex(lines[0], r"^ok    sleep 0\.5.*\s+\d+s  \(2 REVIEW notes\)$")
        self.assertRegex(lines[1], r"^ok    echo 'NOTE: hello'")
        self.assertEqual(lines[2], "      NOTE: hello")
        self.assertRegex(lines[3], r"^ok    echo fast")
        self.assertRegex(lines[4], r"^preflight passed: 3 steps in \d+s$")

    def test_failure_tail_stops_the_rest_and_skips_lint(self):
        t0 = time.time()
        r = self.brief(["echo ok-one",
                        "sleep 30",
                        "sleep 1; for i in $(seq 1 40); do echo line$i; done; exit 3",
                        "just lint"],
                       recipes="lint:\n    @touch linted\n")
        self.assertLess(time.time() - t0, 15)   # sleep 30 was stopped
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        out = r.stdout.splitlines()
        self.assertRegex(out[0], r"^ok    echo ok-one")
        self.assertRegex(out[1], r"^stop  sleep 30 .*\(stopped: sleep 1; for i in")
        self.assertRegex(out[2], r"^FAIL  sleep 1; for i in")
        self.assertIn("line40", out)
        self.assertIn("line11", out)        # the last 30 lines
        self.assertNotIn("line10", out)
        self.assertRegex(r.stdout, r"skip  just lint .*\(not run: sleep 1; for i in")
        self.assertRegex(out[-1], r"^preflight FAILED: 1 of 4 steps")
        self.assertFalse((self.repo / "linted").exists())

    def test_lint_runs_after_the_others(self):
        r = self.brief(["sleep 0.5; touch first", "just lint"],
                       recipes="lint:\n    @test -e first\n")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_cached_check(self):
        recipes = "check:\n    @touch checked\n"
        status = self.t / "status.json"
        r = self.brief(["just check", "echo x"], recipes,
                       env={"PREFLIGHT_CACHED_CHECK": "abcd1234",
                            "PREFLIGHT_STATUS_FILE": str(status)})
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertRegex(r.stdout, r"ok    just check .*\(cached: same flake tree as abcd1234\)")
        self.assertFalse((self.repo / "checked").exists())
        self.assertEqual(json.loads(status.read_text()),
                         {"just check": "cached", "echo x": "ok"})
        r = self.brief(["just check"], recipes,
                       env={"PREFLIGHT_STATUS_FILE": str(status)})
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((self.repo / "checked").exists())
        self.assertEqual(json.loads(status.read_text()), {"just check": "ok"})

    def test_test_jobs_split_across_concurrent_suites(self):
        r = self.brief(["echo \"NOTE: a-test $TEST_JOBS\"",
                        "echo \"NOTE: b-test $TEST_JOBS\"", "true"],
                       env={"TEST_JOBS": "8"})
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("      NOTE: a-test 4", r.stdout.splitlines())
        r = self.brief(["echo \"NOTE: test $TEST_JOBS\""] * 1 + ["echo test2"] * 7,
                       env={"TEST_JOBS": "8"})
        self.assertIn("      NOTE: test 2", r.stdout.splitlines())   # floor of 2

    def test_step_that_cannot_start_fails_without_hanging(self):
        # PATH holds what preflight-brief itself needs, but no bash.
        bin_ = self.t / "nobash"
        bin_.mkdir()
        for tool in ("just", "git", "python3", "env"):
            (bin_ / tool).symlink_to(shutil.which(tool))
        (self.repo / ".justfile").write_text("preflight:\n    @echo hi\n")
        r = subprocess.run(["python3", str(BRIEF)], cwd=self.repo, text=True,
                           capture_output=True, timeout=30,
                           env=dict(self.env, PATH=str(bin_)))
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertRegex(r.stdout, r"FAIL  echo hi")
        self.assertIn("could not start", r.stdout)

    def test_repeated_signals_stop_every_step_once(self):
        (self.repo / ".justfile").write_text(
            "preflight:\n    @sleep 30\n    @sleep 31\n")
        p = subprocess.Popen([str(BRIEF)], cwd=self.repo, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             env=self.env)
        time.sleep(1.0)
        for _ in range(3):
            p.send_signal(signal.SIGTERM)
            p.send_signal(signal.SIGINT)
        _, err = p.communicate(timeout=20)
        self.assertEqual(p.returncode, 130, err)
        self.assertEqual(err.count("interrupted"), 1)

    def test_step_member_outliving_its_leader_is_killed(self):
        pidfile = self.t / "member"
        r = self.brief([f"sh -c 'trap \"\" TERM; exec sleep 30' & echo $! > {pidfile}"])
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIsNone(_proc_start(int(pidfile.read_text())))


if __name__ == "__main__":
    # flake/scripts/parallel_unittest.py: same tests, across processes
    sys.path.insert(0, str(HERE.parents[1] / "flake" / "scripts"))
    import parallel_unittest
    parallel_unittest.main()
