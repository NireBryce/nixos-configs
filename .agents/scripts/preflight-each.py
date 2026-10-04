#!/usr/bin/env python3
"""Is every commit of a multi-commit change green on its own (skill ship
step 0, lessons-learned §15) -- `preflight-brief` on each, one line per
commit. Replaces the throwaway-worktree loop ship spelled out by hand:
`worktree add --detach /tmp/wt <sha> && cd ... && check; worktree
remove`, re-typed per commit and left behind when a check failed.

    preflight-each.py [--jobs N] [<range>]    default origin/experimental..HEAD

Oldest first, in throwaway detached worktrees (one per job, checked out
per commit), so nothing touches a branch pointer or the caller's tree.
Output, one line per commit in commit order, flushed as soon as every
earlier commit has finished, so a background runner can follow it:
    ok   <sha> <subject>  (<n> steps, <s>s)
    FAIL <sha> <subject>  (<s>s)   then preflight-brief's tail, indented
Every commit runs even after a failure; exit 1 if any failed, 2 on usage,
130 on SIGINT/SIGTERM/SIGHUP. `git fetch origin` first, so the default
range is against the trunk as it is now.

`just check` is cached by flake tree, passes only. It evaluates the git
flake at flake/, and the flake reads nothing outside that directory --
checked 2026-10-03 two ways: every relative path literal under flake/
resolves inside it, and a repo holding ONLY flake/ (everything else
deleted) evaluates every host's toplevel and home drvPath, and both
systems' `checks`, to exactly the same derivations as the full repo. So
once a commit passes the check, later commits with the same `git
rev-parse <sha>:flake` print `ok just check (cached: same flake tree as
<sha>)` and skip it. A failed or stopped check is not cached: the next
commit with that tree runs it again (a failure can be transient -- OOM,
the store race flake-check.sh retries). Only that step is cached; every
other step still runs per commit. If the flake ever starts reading
outside flake/ (a `../` path, or `inputs.self`), this cache is wrong --
drop it, or key on the whole tree.

--jobs N (default 1) runs up to N commits at once, each job in its own
worktree. For a range of several commits, memory permitting: N is
clamped to the number of commits, then to what the available memory
covers at CHECK_GIB per concurrent `just check` plus REST_GIB per job
(measured 2026-10-03, below; concurrent checks are at most the number of
distinct flake trees, so a run of doc-only commits fits more jobs).
Available memory is /proc/meminfo's MemAvailable, lowered to the
headroom (memory.max - memory.current) of any limited cgroup v2 ancestor
of this process. If MemAvailable can't be read or parsed, N is 1. Every
cut is reported on stderr. Each job's test suites get CPU/N processes
(TEST_JOBS). A commit whose flake tree an earlier, still running commit
is checking waits for that verdict rather than re-evaluating it.

Cleanup: every worktree is removed on any exit -- success, failure,
SIGINT/SIGTERM/SIGHUP. Each job's process group is TERMed, then KILLed,
and the group must be empty before its worktree is removed (procgroup.py).
Jobs carry PR_SET_PDEATHSIG (Linux), so a SIGKILL of this process TERMs
them too. A worktree that outlives its run anyway (this process
SIGKILLed mid-cleanup) is swept by a later run, under all of these:
  - it was created by this script: `git worktree add --lock --reason
    preflight-each:<host>:<boot id>:<pid>:<start>` (locked from its first
    moment, signals blocked meanwhile), and its admin dir holds
    preflight-each.json with the same fields plus its jobs' pgids;
  - lock reason and marker agree, host and /proc/sys/kernel/random/boot_id
    match this machine, and that pid is gone or now has another start
    time (pid reuse);
  - it is a direct child of the temp dir this run uses, named
    preflight-each.<pid>.*, and is neither the first `git worktree list`
    entry nor this repo's toplevel.
Then its recorded job groups are KILLed (only members started after the
marker's process), and `git worktree remove --force --force` runs (the
double force is for the lock this script set). Its directory is deleted
only by that command; if it refuses, the worktree is left and reported.

PREFLIGHT_EACH_CMD overrides the per-commit command (default: this
directory's preflight-brief.py, run inside the throwaway worktree, where
it reads that commit's own preflight recipe). Tests use it; it runs via
`bash -c`, with PREFLIGHT_CACHED_CHECK / PREFLIGHT_STATUS_FILE set as for
preflight-brief. PREFLIGHT_EACH_MEMINFO, PREFLIGHT_EACH_PROC_CGROUP and
PREFLIGHT_EACH_CGROUP_ROOT stand in for /proc/meminfo, /proc/self/cgroup
and /sys/fs/cgroup, so tests don't depend on the host's memory.
"""
import json
import os
import re
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import procgroup  # noqa: E402

CHECK_STEP = "just check"
# Memory per job, measured on durandal 2026-10-03 (nproc 16, 12.4 GiB):
# `just check` (nix flake check --all-systems --no-build) peaked at 4.8
# GiB RSS -- nix's evaluator, one process (getrusage) -- and the rest of
# preflight-brief, run with the check cached, at ~1.6 GiB summed over its
# process tree (sampled /proc), the parallel test suites' forks included.
CHECK_GIB = 5.0     # a job that evaluates the flake
REST_GIB = 1.5      # every job, check or not
SIGNALS = (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)
TAG = "preflight-each"
MARKER = "preflight-each.json"
NAME_RE = re.compile(r"^preflight-each\.(\d{1,10})\.[A-Za-z0-9_]+$")


def git(*args, check=True, cwd=None):
    r = subprocess.run(["git", *args], capture_output=True, text=True, cwd=cwd)
    if check and r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r


# -- memory ------------------------------------------------------------------
def mem_available_gib():
    """(GiB available or None, where it came from)."""
    path = os.environ.get("PREFLIGHT_EACH_MEMINFO", "/proc/meminfo")
    avail = None
    try:
        with open(path) as f:
            for line in f:
                if line.startswith("MemAvailable:"):
                    avail = int(line.split()[1]) / (1024 * 1024)
                    break
    except (OSError, ValueError, IndexError):
        avail = None
    if avail is None:
        return None, path
    source = "MemAvailable"
    head = cgroup_headroom_gib()
    if head is not None and head < avail:
        avail, source = head, "cgroup memory.max headroom"
    return avail, source


def cgroup_headroom_gib():
    """Smallest memory.max - memory.current over this process's cgroup v2
    path and its ancestors, in GiB; None when no level is limited."""
    root = os.environ.get("PREFLIGHT_EACH_CGROUP_ROOT", "/sys/fs/cgroup")
    try:
        with open(os.environ.get("PREFLIGHT_EACH_PROC_CGROUP", "/proc/self/cgroup")) as f:
            rel = next((l.strip()[3:] for l in f if l.startswith("0::")), None)
    except OSError:
        return None
    if rel is None:
        return None
    best = None
    parts = [p for p in rel.split("/") if p]
    for depth in range(len(parts), -1, -1):
        d = os.path.join(root, *parts[:depth])
        try:
            with open(os.path.join(d, "memory.max")) as f:
                mx = f.read().strip()
            if mx == "max":
                continue
            with open(os.path.join(d, "memory.current")) as f:
                cur = int(f.read().strip())
            room = max(0, int(mx) - cur) / 2**30
        except (OSError, ValueError):
            continue
        best = room if best is None else min(best, room)
    return best


# -- run identity and markers ---------------------------------------------------
def boot_id():
    try:
        with open("/proc/sys/kernel/random/boot_id") as f:
            return f.read().strip()
    except OSError:
        return "no-boot-id"


def identity():
    return {"host": socket.gethostname(), "boot": boot_id(),
            "pid": os.getpid(), "start": procgroup.proc_start(os.getpid())}


def lock_reason(ident):
    return f"{TAG}:{ident['host']}:{ident['boot']}:{ident['pid']}:{ident['start']}"


def parse_reason(reason):
    parts = (reason or "").split(":")
    if len(parts) != 5 or parts[0] != TAG:
        return None
    try:
        pid = int(parts[3])
        start = None if parts[4] == "None" else int(parts[4])
    except (ValueError, OverflowError):
        return None
    if not 0 < pid < 2**31:
        return None
    return {"host": parts[1], "boot": parts[2], "pid": pid, "start": start}


def admin_dirs():
    """worktree path -> its admin dir (<common>/worktrees/<id>)."""
    common = git("rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip()
    out = {}
    base = os.path.join(common, "worktrees")
    try:
        names = os.listdir(base)
    except OSError:
        return out
    for n in names:
        try:
            with open(os.path.join(base, n, "gitdir")) as f:
                dotgit = f.read().strip()
        except OSError:
            continue
        out[os.path.realpath(os.path.dirname(dotgit))] = os.path.join(base, n)
    return out


def worktree_entries():
    """[(path, locked_reason or None)] in `git worktree list` order."""
    out, cur = [], None
    for line in git("worktree", "list", "--porcelain").stdout.splitlines():
        if line.startswith("worktree "):
            cur = [line[9:], None]
            out.append(cur)
        elif line.startswith("locked") and cur is not None:
            cur[1] = line[7:] if line.startswith("locked ") else ""
    return [tuple(e) for e in out]


def read_marker(admin):
    try:
        with open(os.path.join(admin, MARKER)) as f:
            m = json.load(f)
        return m if isinstance(m, dict) else None
    except (OSError, ValueError):
        return None


def run_is_dead(ident):
    start = procgroup.proc_start(ident["pid"])
    if start is None:
        try:
            os.kill(ident["pid"], 0)
        except ProcessLookupError:
            return True
        except (PermissionError, OverflowError):
            return False
        return False     # alive, start unknown (no /proc): leave it
    return ident["start"] is not None and start != ident["start"]


def kill_recorded_groups(marker):
    """KILL members of the run's recorded job groups that started after
    the run itself (so a reused pgid's unrelated members are spared)."""
    floor = marker.get("start")
    pgids = set()
    for g in marker.get("pgids", []):
        try:
            pgids.add(int(g))
        except (ValueError, TypeError, OverflowError):
            pass
    if not pgids or floor is None:
        return
    try:
        pids = [int(p) for p in os.listdir("/proc") if p.isdigit()]
    except OSError:
        return
    for pid in pids:
        try:
            with open(f"/proc/{pid}/stat") as f:
                st = f.read()
            fields = st[st.rindex(")") + 2:].split()
            pgrp, start = int(fields[2]), int(fields[19])
        except (OSError, ValueError, IndexError):
            continue
        if pgrp in pgids and start >= floor:
            try:
                os.kill(pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass


def remove_marked(path, admin):
    """Remove a worktree this script created and locked. Its directory goes
    only through `git worktree remove`; returns whether that succeeded."""
    if not os.path.isdir(path):
        git("worktree", "unlock", path, check=False)
        git("worktree", "prune", check=False)
        return not os.path.isdir(admin)
    return git("worktree", "remove", "--force", "--force", path,
               check=False).returncode == 0


def sweep_stale(tmp, me):
    """Remove worktrees a dead earlier run of this script left; see the
    header for every condition."""
    entries = worktree_entries()
    if not entries:
        return
    top = os.path.realpath(git("rev-parse", "--show-toplevel").stdout.strip())
    first = os.path.realpath(entries[0][0])
    tmp = os.path.realpath(tmp)
    admins = admin_dirs()
    swept, kept = 0, []
    for path, reason in entries[1:]:
        real = os.path.realpath(path)
        if real in (top, first) or os.path.dirname(real) != tmp:
            continue
        if not NAME_RE.match(os.path.basename(real)):
            continue
        ident = parse_reason(reason)
        admin = admins.get(real)
        if ident is None or admin is None:
            continue
        marker = read_marker(admin)
        if (not marker or any(marker.get(k) != ident[k] for k in ident)
                or os.path.realpath(str(marker.get("path", ""))) != real):
            continue
        if ident["host"] != me["host"] or ident["boot"] != me["boot"]:
            continue
        if ident["pid"] == me["pid"] or not run_is_dead(ident):
            continue
        kill_recorded_groups(marker)
        if remove_marked(real, admin):
            swept += 1
        else:
            kept.append(real)
    if swept:
        print(f"preflight-each: removed {swept} worktree(s) left by a killed run",
              file=sys.stderr)
    for k in kept:
        print(f"preflight-each: could not remove stale worktree {k}; left in place",
              file=sys.stderr)


# -- the run -------------------------------------------------------------------
class Runner:
    def __init__(self, shas, flake_trees, jobs, cmd, tmp, ident):
        self.shas, self.flake_trees, self.jobs, self.cmd = shas, flake_trees, jobs, cmd
        self.tmp, self.ident = tmp, ident
        self.worktrees = []         # [(path, admin dir)]
        self.procs = {}             # job index -> Popen
        self.pgids = set()
        self.spawned = []           # every job Popen, finished or not
        self.lock = threading.Lock()
        self.cond = threading.Condition(self.lock)
        self.stopping = False
        self.results = [None] * len(shas)
        self.next = 0
        # flake tree -> who checks it: "owner" is the commit index running
        # its check (claimed in commit order: the earliest commit without a
        # passing verdict), "verdict" "ok" once a check passed, from "sha".
        self.trees = {t: {"owner": None, "verdict": None, "sha": None}
                      for t in flake_trees if t is not None}
        self.printed = 0

    def write_markers_locked(self):
        for path, admin in self.worktrees:
            data = dict(self.ident, path=path, pgids=sorted(self.pgids))
            tmpf = os.path.join(admin, MARKER + ".tmp")
            try:
                with open(tmpf, "w") as f:
                    json.dump(data, f)
                os.replace(tmpf, os.path.join(admin, MARKER))
            except OSError:
                pass

    # -- worktrees ---------------------------------------------------------
    def create_worktrees(self):
        reason = lock_reason(self.ident)
        for _ in range(self.jobs):
            old = signal.pthread_sigmask(signal.SIG_BLOCK, SIGNALS)
            try:
                wt = tempfile.mkdtemp(prefix=f"preflight-each.{os.getpid()}.", dir=self.tmp)
                try:
                    git("worktree", "add", "-q", "--detach", "--lock", "--reason",
                        reason, wt, self.shas[0])
                except RuntimeError:
                    os.rmdir(wt)    # still the empty dir mkdtemp made
                    raise
                admin = git("rev-parse", "--path-format=absolute", "--git-dir",
                            cwd=wt).stdout.strip()
                with self.lock:
                    self.worktrees.append((wt, admin))
                    self.write_markers_locked()
            finally:
                signal.pthread_sigmask(signal.SIG_SETMASK, old)

    def cleanup(self):
        with self.lock:
            self.stopping = True
            # Every group ever spawned: a finished job can leave members behind.
            procs = list(self.spawned)
        left = procgroup.stop(procs)
        for g in left:
            print(f"preflight-each: process group {g} still has members after KILL",
                  file=sys.stderr)
        for path, admin in self.worktrees:
            if not remove_marked(path, admin):
                print(f"preflight-each: could not remove worktree {path}", file=sys.stderr)
        self.worktrees = []

    # -- one commit ----------------------------------------------------------
    def run_commit(self, job, i):
        sha = self.shas[i]
        wt = self.worktrees[job][0]
        start = time.time()
        subject = git("log", "-1", "--format=%s", sha).stdout.strip()
        git("-C", wt, "checkout", "-q", "--detach", "--force", sha)
        git("-C", wt, "clean", "-qfdx")

        env = dict(os.environ)
        env.pop("PREFLIGHT_CACHED_CHECK", None)
        if self.jobs > 1:
            env["TEST_JOBS"] = str(max(1, (os.cpu_count() or 1) // self.jobs))
        tree = self.flake_trees[i]
        owner = False
        entry = None
        if tree is not None:
            entry = self.trees[tree]
            with self.cond:
                # Wait while an earlier commit with this tree is checking it.
                while (entry["owner"] not in (None, i) and entry["verdict"] is None
                       and not self.stopping):
                    self.cond.wait(0.5)
                if entry["verdict"] == "ok":
                    env["PREFLIGHT_CACHED_CHECK"] = entry["sha"][:8]
                else:
                    entry["owner"], owner = i, True
        fd, status = tempfile.mkstemp(prefix="preflight-each-status.")
        os.close(fd)
        fd, log = tempfile.mkstemp(prefix="preflight-each-log.")
        os.close(fd)
        env["PREFLIGHT_STATUS_FILE"] = status
        try:
            with open(log, "wb") as out:
                with self.lock:
                    if self.stopping:
                        return
                    p = procgroup.spawn(["bash", "-c", self.cmd], cwd=wt, env=env,
                                        stdout=out, stderr=subprocess.STDOUT,
                                        stdin=subprocess.DEVNULL)
                    self.procs[job] = p
                    self.spawned.append(p)
                    self.pgids.add(p.pid)
                    self.write_markers_locked()
                rc = p.wait()
                # The job is over: nothing of it may run on into the next
                # commit's checkout of this worktree.
                procgroup.stop([p], grace=0.5)
                with self.lock:
                    self.procs.pop(job, None)
            try:
                with open(status) as f:
                    verdict = json.load(f).get(CHECK_STEP)
            except (OSError, ValueError, AttributeError):
                verdict = None
            if owner and verdict == "ok":
                with self.cond:
                    entry["verdict"], entry["sha"] = "ok", sha
            with open(log, errors="replace") as f:
                text = f.read().splitlines()
        finally:
            if owner:
                with self.cond:
                    if entry["verdict"] is None:
                        # Not passed (failed, stopped, or a stand-in
                        # command): the next commit with this tree checks.
                        entry["owner"] = None
                    self.cond.notify_all()
            os.unlink(status)
            os.unlink(log)
        secs = round(time.time() - start)
        short = sha[:8]
        if rc == 0:
            steps = next((m.group(1) for l in reversed(text)
                          for m in [re.match(r"^preflight passed: (\d+) steps", l)] if m), "?")
            line = [f"ok   {short} {subject}  ({steps} steps, {secs}s)"]
        else:
            line = [f"FAIL {short} {subject}  ({secs}s)"]
            line += ["     " + l for l in text[-40:]]
        with self.lock:
            self.results[i] = (rc, line)
            self.flush_locked()

    def flush_locked(self):
        while self.printed < len(self.results) and self.results[self.printed]:
            print("\n".join(self.results[self.printed][1]), flush=True)
            self.printed += 1

    def worker(self, job):
        while True:
            with self.lock:
                if self.stopping or self.next >= len(self.shas):
                    return
                i = self.next
                self.next += 1
                # Claim the tree's check here, in commit order, not after
                # this job's checkout -- another job may get there first.
                entry = self.trees.get(self.flake_trees[i])
                if entry and entry["owner"] is None and entry["verdict"] is None:
                    entry["owner"] = i
            try:
                self.run_commit(job, i)
            except Exception as e:  # a git step failed: report it, keep going
                with self.lock:
                    if entry and entry["owner"] == i and entry["verdict"] is None:
                        entry["owner"] = None   # let a waiter check this tree
                        self.cond.notify_all()
                    self.results[i] = (1, [f"FAIL {self.shas[i][:8]}  ({e})"])
                    self.flush_locked()

    def run(self):
        threads = [threading.Thread(target=self.worker, args=(j,), daemon=True)
                   for j in range(self.jobs)]
        for t in threads:
            t.start()
        for t in threads:
            while t.is_alive():
                t.join(0.2)     # short joins: signals reach the main thread
        return 1 if any(r is None or r[0] != 0 for r in self.results) else 0


def clamp_jobs(want, shas, flake_trees):
    jobs = min(want, len(shas))
    if jobs <= 1:
        return jobs
    avail, source = mem_available_gib()
    if avail is None:
        print(f"preflight-each: --jobs {want} reduced to 1: can't read MemAvailable "
              f"from {source}", file=sys.stderr)
        return 1
    # At most one check per distinct flake tree runs at a time (a commit
    # sharing a running commit's tree waits for its verdict).
    trees = len({t or s for t, s in zip(flake_trees, shas)})

    def need(n):
        return min(n, trees) * CHECK_GIB + n * REST_GIB
    fit = max([n for n in range(1, jobs + 1) if need(n) <= avail] or [1])
    if fit < jobs:
        print(f"preflight-each: --jobs {want} reduced to {fit}: {source} "
              f"{avail:.1f} GiB; {jobs} jobs over {trees} flake tree(s) need "
              f"~{need(jobs):.1f} GiB ({CHECK_GIB:g} per concurrent `just check` "
              f"+ {REST_GIB:g} per job)", file=sys.stderr)
    return fit


def main(argv):
    jobs, rest = 1, []
    it = iter(argv)
    for a in it:
        if a in ("-j", "--jobs"):
            a = next(it, "")
        elif a.startswith("--jobs="):
            a = a.split("=", 1)[1]
        else:
            rest.append(a)
            continue
        if not a.isdigit() or int(a) < 1:
            print("usage: preflight-each.py [--jobs N] [<range>]", file=sys.stderr)
            return 2
        jobs = int(a)
    if len(rest) > 1 or any(r.startswith("-") for r in rest):
        print("usage: preflight-each.py [--jobs N] [<range>]", file=sys.stderr)
        return 2
    rng = rest[0] if rest else "origin/experimental..HEAD"
    cmd = os.environ.get("PREFLIGHT_EACH_CMD") or os.path.join(HERE, "preflight-brief.py")

    top = git("rev-parse", "--show-toplevel", check=False)
    if top.returncode != 0:
        return 2
    os.chdir(top.stdout.strip())
    if git("fetch", "-q", "origin", check=False).returncode != 0:
        print("warning: git fetch origin failed; using local refs", file=sys.stderr)

    r = git("rev-list", "--reverse", rng, check=False)
    shas = r.stdout.split() if r.returncode == 0 else []
    if not shas:
        tip = rng.split("..")[-1] or "HEAD"
        if r.returncode != 0 or git("rev-parse", "-q", "--verify", f"{tip}^{{commit}}",
                                    check=False).returncode != 0:
            print(f"bad range: {rng}", file=sys.stderr)
            return 2
        print(f"no commits in {rng}")
        return 0

    tmp = tempfile.gettempdir()
    ident = identity()
    sweep_stale(tmp, ident)
    # None: no flake/ at that commit (fixture repos), so nothing to cache.
    flake_trees = []
    for s in shas:
        r = git("rev-parse", "-q", "--verify", f"{s}:flake", check=False)
        flake_trees.append(r.stdout.strip() if r.returncode == 0 else None)
    jobs = clamp_jobs(jobs, shas, flake_trees)

    runner = Runner(shas, flake_trees, jobs, cmd, tmp, ident)

    def on_signal(signum, _frame):
        for s in SIGNALS:
            signal.signal(s, signal.SIG_IGN)
        print("interrupted", file=sys.stderr, flush=True)
        runner.cleanup()
        os._exit(130)   # worker threads are daemons mid-wait; don't join them

    for s in SIGNALS:
        signal.signal(s, on_signal)
    try:
        runner.create_worktrees()
        where = runner.worktrees[0][0] if jobs == 1 else f"{jobs} worktrees"
        print(f"preflight-each: {len(shas)} commits in {rng} "
              f"({'worktree ' if jobs == 1 else ''}{where})", flush=True)
        return runner.run()
    finally:
        for s in SIGNALS:
            signal.signal(s, signal.SIG_IGN)
        runner.cleanup()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
