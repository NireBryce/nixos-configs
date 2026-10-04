"""Run a unittest module's tests across processes -- the stdlib-only
drop-in for `unittest.main()` that the slow fixture suites call instead.

Why: test_guards.py spent ~50s of its ~60s in GitGuardPreToolUse, every
test a handful of real hook runs at ~0.3s each (bash + jq + git against a
throwaway repo), one after another on a 16-core host. Nothing in those
tests depends on another test, so the fix is scheduling, not fewer
assertions: every test still runs, exactly once, with its own setUp.

    parallel_unittest.main()        # in place of unittest.main()

How it splits: the module's suite is flattened to single tests, and each
becomes one unit of work -- except a class with its own setUpClass /
tearDownClass (or a module with setUpModule), which stays one unit so
its class fixture runs once and in one process, as unittest would.
Each unit runs in its own forked child (the module is already imported in
the parent, so nothing is re-imported -- which a test file run as
__main__ could not do under spawn), at most TEST_JOBS at a time, and
sends its result back over a pipe. Output is buffered per test
(unittest's `buffer=True`), so a failure's captured stdout/stderr comes
back with its traceback instead of interleaving across children.

A child that dies without sending a result (os._exit, a signal, the OOM
killer) or outlives TEST_UNIT_TIMEOUT seconds (default 600; it is then
KILLed) is reported as an ERROR for every test in its unit, with the exit
status, and the run fails. The other units still run.

What prints: unittest's own summary shape -- each failure/error block in
the original test order, then `Ran N tests in Xs (J processes)` and
`OK` / `FAILED (failures=.., errors=..)`. Exit status is unittest's: 0
only if every test passed (skips and expected failures included), 1 on
any failure or error, 5 when the module has no tests at all.

Falls back to plain unittest.main() -- same tests, serial, unittest's
own output -- when command-line arguments name tests (`python3
test_x.py SomeCase.test_y`, `-k`, `-v`), when TEST_JOBS=1, or where
fork is unavailable. TEST_JOBS=N caps the process count (default: CPU
count); preflight-brief and preflight-each set it.
"""
import multiprocessing
import multiprocessing.connection
import os
import sys
import time
import unittest


def _units(suite):
    """Flatten `suite` into a list of runnable units, in order: a single
    test, or a whole class when the class (or its module) has a class- or
    module-level fixture that must run once per process."""
    flat = []

    def walk(s):
        for t in s:
            if isinstance(t, unittest.TestSuite):
                walk(t)
            else:
                flat.append(t)
    walk(suite)

    units, grouped = [], {}
    for t in flat:
        cls = type(t)
        mod = sys.modules.get(cls.__module__)
        shared = (cls.setUpClass.__func__ is not unittest.TestCase.setUpClass.__func__
                  or cls.tearDownClass.__func__ is not unittest.TestCase.tearDownClass.__func__
                  or hasattr(mod, "setUpModule") or hasattr(mod, "tearDownModule"))
        if not shared:
            units.append([t])
        elif cls in grouped:
            grouped[cls].append(t)
        else:
            grouped[cls] = [t]
            units.append(grouped[cls])
    return units


def _child(unit, conn):
    """In the forked child: run `unit`, send picklable results, exit."""
    result = unittest.TestResult()
    result.buffer = True
    unittest.TestSuite(unit).run(result)
    conn.send({
        "run": result.testsRun,
        "failures": [(str(t), tb) for t, tb in result.failures],
        "errors": [(str(t), tb) for t, tb in result.errors],
        "skipped": len(result.skipped),
        "expected": len(result.expectedFailures),
        "unexpected": [str(t) for t in result.unexpectedSuccesses],
    })
    conn.close()


def _crashed(unit, why):
    return {"run": len(unit), "failures": [], "skipped": 0, "expected": 0,
            "unexpected": [],
            "errors": [(str(t), f"test process {why}; no result was "
                                f"returned for this unit\n") for t in unit]}


def _env_int(name, default):
    try:
        return int(os.environ.get(name, "")) or default
    except ValueError:
        return default


def run_units(units, jobs, timeout):
    """Run each unit in its own forked child, `jobs` at a time; return one
    result dict per unit, in unit order."""
    ctx = multiprocessing.get_context("fork")
    results = [None] * len(units)
    running = {}            # reader conn -> (index, process, deadline)
    pending = list(range(len(units)))
    while pending or running:
        while pending and len(running) < jobs:
            i = pending.pop(0)
            reader, writer = ctx.Pipe(duplex=False)
            p = ctx.Process(target=_child, args=(units[i], writer))
            p.start()
            writer.close()
            running[reader] = (i, p, time.time() + timeout)
        ready = multiprocessing.connection.wait(list(running), timeout=1.0)
        for reader in ready:
            i, p, _ = running.pop(reader)
            try:
                results[i] = reader.recv()
            except (EOFError, OSError):
                p.join()
                results[i] = _crashed(units[i], f"exited with status {p.exitcode}")
            else:
                p.join()
            reader.close()
        now = time.time()
        for reader, (i, p, deadline) in list(running.items()):
            if now > deadline:
                p.kill()
                p.join()
                running.pop(reader)
                reader.close()
                results[i] = _crashed(units[i], f"exceeded {timeout}s and was killed")
    return results


def main(module="__main__"):
    jobs = _env_int("TEST_JOBS", os.cpu_count() or 1)
    if (len(sys.argv) > 1 or jobs == 1
            or "fork" not in multiprocessing.get_all_start_methods()):
        unittest.main(module=module)
        return  # unittest.main exits; unreachable

    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[module])
    units = _units(suite)
    out = sys.stderr  # where unittest.main reports, too
    if not units:
        print("-" * 70, file=out)
        print("Ran 0 tests\n\nNO TESTS RAN", file=out)
        sys.exit(5)
    jobs = min(jobs, len(units))
    start = time.time()
    results = run_units(units, jobs, _env_int("TEST_UNIT_TIMEOUT", 600))
    took = time.time() - start

    run = sum(r["run"] for r in results)
    failures = [f for r in results for f in r["failures"]]
    errors = [e for r in results for e in r["errors"]]
    unexpected = [u for r in results for u in r["unexpected"]]
    skipped = sum(r["skipped"] for r in results)
    expected = sum(r["expected"] for r in results)
    for kind, items in (("ERROR", errors), ("FAIL", failures)):
        for name, tb in items:
            print("=" * 70, file=out)
            print(f"{kind}: {name}", file=out)
            print("-" * 70, file=out)
            print(tb, file=out)
    for name in unexpected:
        print(f"UNEXPECTED SUCCESS: {name}", file=out)
    print("-" * 70, file=out)
    print(f"Ran {run} test{'s' if run != 1 else ''} in {took:.3f}s "
          f"({jobs} processes)\n", file=out)
    extras = [f"{k}={v}" for k, v in (("skipped", skipped),
                                      ("expected failures", expected)) if v]
    if failures or errors or unexpected:
        counts = [f"{k}={len(v)}" for k, v in (("failures", failures),
                                                ("errors", errors),
                                                ("unexpected successes", unexpected)) if v]
        print(f"FAILED ({', '.join(counts + extras)})", file=out)
        sys.exit(1)
    if run == 0:
        print("NO TESTS RAN", file=out)
        sys.exit(5)
    print("OK" + (f" ({', '.join(extras)})" if extras else ""), file=out)
    sys.exit(0)
