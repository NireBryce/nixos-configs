#!/usr/bin/env python3
"""Did preflight pass -- and if not, which step and why -- in one line per
step instead of preflight's few hundred, and in the time of its slowest
step instead of the sum of all of them. Replaces the
`just preflight 2>&1 | grep -E "^OK|FAIL|all checks|..." | tail` agents
kept hand-writing to skim it (skill ship, step 0).

Same steps as `just preflight`, read from the recipe itself (`just --show
preflight`), so a step added there is picked up here with no edit. That
read is verbatim -- `--show` does not apply `{{...}}` substitutions, and
each line runs as printed (`bash -c`) -- so a preflight step must use
literal paths (`@flake/scripts/x.sh`, like the recurring-test step), or it
dies with `{{: command not found`. Found live, 2026-09-29, on a
`{{scripts}}` step.

Concurrency (2026-10-03; serial before, ~130s, of which ~45s `just check`
and ~40-60s `just guards-test`): every step starts at once, each in its
own process group, except SERIAL_LAST, which runs alone after the rest
have passed. Safe because the concurrent steps write nothing in the repo
tree: measured by running all of them against a marker file (only git's
own index refresh under .git/ moved, which git serializes with
index.lock; a concurrent reader skips the refresh, it does not fail). The
test steps build their fixtures in mkdtemp dirs, never the checkout.
`just lint` is the exception: lint.py rewrites the tracked
flake/scripts/lint-baseline.json when a count drops, and `just check`
hashes the flake/ tree while it evaluates -- so it goes last, alone.
A new step that writes into the tree belongs in SERIAL_LAST.

The suites using flake/scripts/parallel_unittest.py would each start a
process per CPU; run side by side that oversubscribes the machine. So
every step gets TEST_JOBS = max(2, base // n), n being the concurrent
steps whose command names a test (`test` in it), base the inherited
TEST_JOBS (preflight-each sets it under --jobs) or the CPU count.

`just preflight` itself (what CI runs) stays serial, deliberately: its
body IS the step list this script and preflight-mirror-test both parse,
and its full sequential output is what a red CI log is read from. CI got
faster anyway, through the parallel test runner the slow suites now use.

Output, one line per step in the recipe's order, printed as soon as every
step before it has finished:
    ok    <step>   <s>s  (<n> REVIEW notes)    -- plus its NOTE lines
    FAIL  <step>   <s>s                        -- then its last 30 lines
    stop  <step>   (stopped: <step> failed)    -- killed, see below
    skip  <step>   (not run: <step> failed)    -- SERIAL_LAST, never started
Fail-fast like the serial version, which stopped at the first failure: the
first step to fail (in time, not order) stops every step still running.
Every step that did fail is printed with its tail. wiki-lint's REVIEW
notes don't fail it; they're counted on its line so they aren't lost. A
step's warn-only NOTE lines (hooks-path-note.sh) are echoed under it.
A step that can't be started at all is a FAIL with the error as its tail.
Exit 0 only if every step passed. Stopping a step means: TERM its group,
then KILL it, and wait until the group is empty (procgroup.py); steps
carry PR_SET_PDEATHSIG on Linux, so they are TERMed if this process is
SIGKILLed. SIGINT/SIGTERM/SIGHUP stop every step and exit 130.

For preflight-each (not meant to be set by hand):
  PREFLIGHT_CACHED_CHECK=<sha>  report `just check` as passed instead of
      running it -- the flake tree at <sha> is identical and passed it,
      and the flake reads nothing outside flake/ (preflight-each.py's
      header). Only passes are cached.
  PREFLIGHT_STATUS_FILE=<path>  write {step: ok|fail|stop|skip|cached}
      as JSON when done, so the caller can cache `just check`'s verdict.
"""
import json
import os
import queue
import signal
import subprocess
import sys
import tempfile
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import procgroup  # noqa: E402

SERIAL_LAST = {"just lint"}
CHECK_STEP = "just check"
TAIL = 30
SIGNALS = (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)

procs = {}          # index -> Popen, while running
# Reentrant: the signal handler runs stop_all on the main thread, which may
# already hold it inside stop_all.
procs_lock = threading.RLock()
stopped = set()     # indices that were still running when stop_all fired
stopping = False


def read_steps():
    out = subprocess.run(["just", "--show", "preflight"], capture_output=True,
                         text=True)
    if out.returncode != 0:
        sys.exit(f"just --show preflight failed:\n{out.stderr}")
    return [l[5:] for l in out.stdout.splitlines() if l.startswith("    @")]


def stop_all():
    """Stop every running step (procgroup.stop); a step not yet started
    never starts."""
    global stopping
    with procs_lock:
        stopping = True
        stopped.update(procs)
        running = list(procs.values())
    procgroup.stop(running)


def on_signal(signum, _frame):
    for s in SIGNALS:
        signal.signal(s, signal.SIG_IGN)
    print("interrupted", file=sys.stderr, flush=True)
    stop_all()
    sys.exit(130)


class Step:
    def __init__(self, index, cmd, logdir):
        self.index, self.cmd = index, cmd
        self.log = os.path.join(logdir, f"{index}.log")
        self.state = None        # ok | fail | stop | skip | cached
        self.secs = 0
        self.rc = None
        self.why = ""

    def run(self, env, done):
        """Run in a thread: start, wait, record, and always post to `done`."""
        start = time.time()
        rc = 1
        try:
            with open(self.log, "wb") as log:
                with procs_lock:
                    if stopping:
                        stopped.add(self.index)
                        p = None
                    else:
                        try:
                            # bash -u -o pipefail: what the serial version's
                            # `eval` ran under.
                            p = procgroup.spawn(
                                ["bash", "-u", "-o", "pipefail", "-c", self.cmd],
                                stdout=log, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, env=env)
                        except OSError as e:
                            log.write(f"could not start: {e}\n".encode())
                            p = None
                        else:
                            procs[self.index] = p
                rc = p.wait() if p else (-signal.SIGTERM if self.index in stopped else 1)
                if p:
                    # The step is over: stop anything it left running.
                    procgroup.stop([p], grace=0.5)
        except Exception as e:  # noqa: BLE001 -- reported as this step's failure
            try:
                with open(self.log, "ab") as log:
                    log.write(f"preflight-brief: {e!r}\n".encode())
            except OSError:
                pass
            rc = 1
        finally:
            with procs_lock:
                procs.pop(self.index, None)
            self.secs = round(time.time() - start)
            self.rc = rc
            done.put(self)

    def lines(self):
        try:
            with open(self.log, errors="replace") as f:
                return f.read().splitlines()
        except OSError:
            return []


def report(step, width):
    if step.state == "ok":
        lines = step.lines()
        notes = sum(1 for l in lines if l.startswith("REVIEW"))
        extra = f"  ({notes} REVIEW notes)" if notes else ""
        print(f"ok    {step.cmd:<{width}} {step.secs:4d}s{extra}")
        for l in lines:
            if l.startswith("NOTE"):
                print(f"      {l}")
    elif step.state == "fail":
        print(f"FAIL  {step.cmd:<{width}} {step.secs:4d}s\n")
        for l in step.lines()[-TAIL:]:
            print(l)
        print()
    elif step.state == "cached":
        print(f"ok    {step.cmd:<{width}}    -  ({step.why})")
    else:
        print(f"{step.state:<4}  {step.cmd:<{width}}    -  ({step.why})")
    sys.stdout.flush()


def next_done(done):
    """done.get(), in short timeouts: a signal the kernel delivers to a
    worker thread only sets CPython's flag, and the handler runs when the
    main thread next executes bytecode -- never, while it sits in an
    untimed lock wait. Seen as a hang under repeated SIGINT/SIGTERM."""
    while True:
        try:
            return done.get(timeout=0.2)
        except queue.Empty:
            pass


def test_jobs(env, concurrent):
    try:
        base = int(env.get("TEST_JOBS", "")) or 0
    except ValueError:
        base = 0
    base = base or os.cpu_count() or 1
    n = sum(1 for s in concurrent if "test" in s.cmd) or 1
    return str(max(2, base // n))


def main():
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True)
    if top.returncode != 0:
        sys.exit(2)
    os.chdir(top.stdout.strip())
    cmds = read_steps()
    if not cmds:
        print("no steps found in the preflight recipe")
        sys.exit(2)
    for s in SIGNALS:
        signal.signal(s, on_signal)

    width = 44
    cached = os.environ.get("PREFLIGHT_CACHED_CHECK", "")
    env = {k: v for k, v in os.environ.items()
           if k not in ("PREFLIGHT_CACHED_CHECK", "PREFLIGHT_STATUS_FILE")}
    started = time.time()
    with tempfile.TemporaryDirectory(prefix="preflight-brief.") as logdir:
        steps = [Step(i, c, logdir) for i, c in enumerate(cmds)]
        concurrent = [s for s in steps if s.cmd not in SERIAL_LAST]
        serial = [s for s in steps if s.cmd in SERIAL_LAST]
        env["TEST_JOBS"] = test_jobs(env, concurrent)
        done = queue.Queue()
        first_fail = None
        pending = 0

        def finish(step):
            nonlocal first_fail
            if step.rc == 0:
                step.state = "ok"
            elif step.index in stopped and first_fail is not None:
                step.state = "stop"
                step.why = f"stopped: {first_fail.cmd} failed"
            else:
                step.state = "fail"
                if first_fail is None:
                    first_fail = step

        for s in concurrent:
            if s.cmd == CHECK_STEP and cached:
                s.state, s.why = "cached", f"cached: same flake tree as {cached}"
                continue
            threading.Thread(target=s.run, args=(env, done), daemon=True).start()
            pending += 1

        printed = 0

        def flush_ready(upto):
            nonlocal printed
            while printed < upto and steps[printed].state is not None:
                report(steps[printed], width)
                printed += 1

        while pending:
            s = next_done(done)
            pending -= 1
            had_fail = first_fail is not None
            finish(s)
            if first_fail is not None and not had_fail:
                stop_all()
            flush_ready(len(steps))

        for s in serial:
            if first_fail is not None:
                s.state, s.why = "skip", f"not run: {first_fail.cmd} failed"
                continue
            flush_ready(s.index)
            threading.Thread(target=s.run, args=(env, done), daemon=True).start()
            finish(next_done(done))
        flush_ready(len(steps))

        status = os.environ.get("PREFLIGHT_STATUS_FILE")
        if status:
            with open(status, "w") as f:
                json.dump({s.cmd: s.state for s in steps}, f)

    wall = round(time.time() - started)
    if first_fail is None:
        print(f"preflight passed: {len(steps)} steps in {wall}s")
        sys.exit(0)
    failed = sum(1 for s in steps if s.state == "fail")
    print(f"preflight FAILED: {failed} of {len(steps)} steps ({wall}s)")
    sys.exit(1)


if __name__ == "__main__":
    main()
