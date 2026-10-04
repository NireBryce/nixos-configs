"""Process-group helpers shared by preflight-brief.py and preflight-each.py.

Both run children in their own process groups (a session each), so a
child's whole tree -- just, nix, a test suite's forks -- can be stopped
as one, and a ^C to the caller's terminal reaches only the caller, which
then stops its children deliberately.

spawn():  Popen in a new session (start_new_session, done in C after
          fork). On Linux, when util-linux's setpriv is on PATH, the child
          runs as `setpriv --pdeathsig TERM -- <argv>`, so if the caller is
          SIGKILLed the child is TERMed by the kernel instead of running on
          (preflight-brief, as such a child, then stops its own steps); the
          death signal survives the exec into <argv>, and fires when the
          spawning *thread* exits, so callers spawn from a thread that
          waits for the child. Deliberately no preexec_fn: Python code
          between fork and exec could run an inherited pending signal
          handler in the child, which can block on a lock another parent
          thread held at fork time, and the parent's Popen with it; with
          start_new_session and setpriv no Python runs there.
stop():   TERM every group, wait up to `grace` for the leaders, then KILL
          every group unconditionally (members can outlive their leader),
          reap the leaders, and wait until each group has no members left,
          so nothing still runs in a directory the caller is about to
          remove. Returns the pgids still populated after `settle`
          seconds (normally none).
"""
import os
import shutil
import signal
import subprocess
import sys
import time

_SETPRIV = shutil.which("setpriv") if sys.platform.startswith("linux") else None


def spawn(argv, **kw):
    kw.pop("start_new_session", None)
    kw.pop("preexec_fn", None)
    if _SETPRIV:
        argv = [_SETPRIV, "--pdeathsig", "TERM", "--", *argv]
    return subprocess.Popen(argv, start_new_session=True, **kw)


def group_alive(pgid):
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _signal_group(pgid, sig):
    try:
        os.killpg(pgid, sig)
    except (ProcessLookupError, PermissionError):
        pass


def stop(procs, grace=3.0, settle=5.0):
    procs = list(procs)
    for p in procs:
        _signal_group(p.pid, signal.SIGTERM)
    deadline = time.time() + grace
    for p in procs:
        try:
            p.wait(max(0.0, deadline - time.time()))
        except subprocess.TimeoutExpired:
            pass
    for p in procs:
        _signal_group(p.pid, signal.SIGKILL)
    deadline = time.time() + settle
    for p in procs:
        try:
            p.wait(max(0.0, deadline - time.time()))
        except subprocess.TimeoutExpired:
            pass
    left = [p.pid for p in procs]
    while left and time.time() < deadline:
        left = [g for g in left if group_alive(g)]
        if left:
            time.sleep(0.05)
    return left


def proc_start(pid):
    """Start time of `pid` in clock ticks since boot (/proc/<pid>/stat
    field 22), or None if there is no such process or no /proc."""
    try:
        with open(f"/proc/{pid}/stat") as f:
            st = f.read()
        return int(st[st.rindex(")") + 2:].split()[19])
    except (OSError, ValueError, IndexError, OverflowError):
        return None
