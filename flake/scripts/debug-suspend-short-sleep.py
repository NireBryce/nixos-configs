#!/usr/bin/env python3
"""Short-sleep test for the nire-durandal suspend hang.

From wiki/experiments/durandal-auto-suspend-hang.md ("Short sleeps and the PSU
hypothesis"). In the probe dumps 6 of 28 cycles that slept 300 s or less hung,
against 3 of 71 longer ones (p about 0.014, but the 300 s split was picked
after looking and about 15 fields were compared, so a lead and not a result).
The shortest hang slept 36 s and 14 cycles of 33 s or less were all clean, so
the default delays start at 30 s. This runs real S3 cycles at fixed delays,
shuffled so order cannot explain a pattern, and logs each one so a hung cycle
is recoverable after a hard reset.

    debug-suspend-short-sleep.py run [--delays 30,45,60,90,120,180] [--rounds 6]
                                     [--wake rtc|key] [--settle 20] [--seed N]
                                     [--min-delay 15] [--wait-extra 180] [--dry-run]
    debug-suspend-short-sleep.py report

`run` suspends the machine for real (`systemctl suspend`), so close anything
you care about first. Each round goes through every delay once, in a random
order; the defaults are 36 cycles. Delays under --min-delay are refused: the
alarm starts counting before the probe and logind have finished, and an alarm
that fires before the machine is in S3 wakes nothing, which looks exactly like
a hang.

  --wake rtc   (default) sets an RTC alarm with `sudo rtcwake -m no -s N`
               immediately before suspending. Exact delays, no hands. A
               different wake path from the keyboard: a hang here is
               informative, a clean run does not clear the keyboard path.
  --wake key   prints the delay and suspends; wake it with a key press about
               N seconds after the screen goes dark.

`systemctl suspend` returns as soon as the suspend is queued, so a returned
command says nothing about the wake. The script reads the kernel's
/sys/power/suspend_stats/success counter before suspending and waits until it
rises: that is the resume. A `resumed` line carries the wall-clock seconds
between the two. If the counter has not moved after delay + --wait-extra
seconds the machine never slept (a missed alarm, a refused suspend) and a
`timeout` line is written.

The log is ~/.local/state/debug-suspend/short-sleep.log (or under
XDG_STATE_HOME). A `suspend` line is written and synced BEFORE each suspend. A
cycle with `suspend` and no `resumed`, `failed` or `timeout` line hung or was
interrupted: after a hard reset, `report` shows it. The probe's own pre/post
dumps and drive power-cycle deltas are the hang detector:

    just agent debug-suspend-hangs

`report` prints, per delay, cycles started and resumed, and lists every cycle
that is unresolved. A torn last line (power cut mid-write) is ignored.
--dry-run logs without suspending or calling sudo.
"""
import argparse
import os
import random
import subprocess
import sys
import time
from collections import defaultdict
from pathlib import Path

DEFAULT_DELAYS = "30,45,60,90,120,180"
RESOLVED_EVENTS = {"resumed", "failed", "timeout"}


def refuse_root():
    """Home is /root under sudo, and /root is wiped on boot on this host."""
    if os.geteuid() == 0:
        sys.exit("debug-suspend-short-sleep: run as your user, not root or under sudo "
                 "(the log would land in /root, which is wiped on boot; rtcwake asks for sudo itself)")


def log_path():
    state_home = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(state_home) / "debug-suspend" / "short-sleep.log"


def stats_dir():
    return Path(os.environ.get("SUSPEND_STATS_DIR") or "/sys/power/suspend_stats")


def read_success_count():
    """The kernel's count of completed suspend cycles, or None if unreadable."""
    try:
        return int((stats_dir() / "success").read_text().strip())
    except (OSError, ValueError):
        return None


def append_synced(path, line):
    """Append a line and force it to disk: a hung machine loses nothing else."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as handle:
        handle.write(line + "\n")
        handle.flush()
        os.fsync(handle.fileno())


def plan_cycles(delays, rounds, seed):
    """Each round holds every delay once, shuffled."""
    rng = random.Random(seed)
    cycles = []
    for _ in range(rounds):
        order = list(delays)
        rng.shuffle(order)
        cycles.extend(order)
    return cycles


def now_stamp():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def wait_for_resume(success_before, deadline):
    """Poll until the kernel's success counter rises or the deadline passes."""
    while time.time() < deadline:
        count = read_success_count()
        if count is not None and success_before is not None and count > success_before:
            return True
        time.sleep(0.5)
    return False


def run_cycle(path, run_id, cycle, delay, options):
    key = f"run={run_id} cycle={cycle} delay={delay}"
    append_synced(path, f"{now_stamp()} suspend {key} wake={options.wake}")
    if options.dry_run:
        append_synced(path, f"{now_stamp()} resumed {key} slept=0.0")
        return True
    success_before = read_success_count()
    if success_before is None:
        append_synced(path, f"{now_stamp()} failed {key} reason=suspend_stats-unreadable")
        print("cannot read /sys/power/suspend_stats/success; stopping", file=sys.stderr)
        return False
    started = time.time()
    try:
        if options.wake == "rtc":
            subprocess.run(["sudo", "rtcwake", "-m", "no", "-s", str(delay)], check=True)
        else:
            print(f"cycle {cycle}: wake with a key about {delay} s after the screen goes dark")
        subprocess.run(["systemctl", "suspend"], check=True)
    except (subprocess.CalledProcessError, OSError) as error:
        append_synced(path, f"{now_stamp()} failed {key} reason={type(error).__name__}")
        print(f"cycle {cycle}: could not start the suspend ({error}); stopping", file=sys.stderr)
        return False
    if wait_for_resume(success_before, started + delay + options.wait_extra):
        append_synced(path, f"{now_stamp()} resumed {key} slept={time.time() - started:.1f}")
    else:
        append_synced(path, f"{now_stamp()} timeout {key} waited={time.time() - started:.1f}")
        print(f"cycle {cycle}: the machine never slept (see `timeout` in the log)", file=sys.stderr)
    return True


def command_run(options):
    if not options.dry_run:
        refuse_root()
    delays = [int(value) for value in options.delays.split(",")]
    too_short = [delay for delay in delays if delay < options.min_delay]
    if too_short:
        print(f"delays {too_short} are under --min-delay {options.min_delay}", file=sys.stderr)
        return 2
    seed = options.seed if options.seed is not None else random.randrange(1_000_000)
    run_id = time.strftime("%Y%m%dT%H%M%S")
    path = log_path()
    cycles = plan_cycles(delays, options.rounds, seed)
    print(f"run {run_id}: {len(cycles)} cycles, seed {seed}, wake {options.wake}, log {path}")
    for cycle, delay in enumerate(cycles, start=1):
        print(f"cycle {cycle}/{len(cycles)}: {delay} s")
        if not run_cycle(path, run_id, cycle, delay, options):
            return 1
        time.sleep(0 if options.dry_run else options.settle)
    print("done; check hangs with: just agent debug-suspend-hangs")
    return 0


def parse_fields(parts):
    return dict(part.split("=", 1) for part in parts if "=" in part)


def parse_log(path):
    """Return ({delay: [started, resumed]}, unresolved [(run, cycle, delay, why)]).

    Lines that do not parse (a torn last line) are skipped.
    """
    started = []
    resolution = {}
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split()
        if len(parts) < 3:
            continue
        event, fields = parts[1], parse_fields(parts[2:])
        if not {"run", "cycle", "delay"} <= fields.keys() or not fields["delay"].isdigit():
            continue
        key = (fields["run"], fields["cycle"])
        if event == "suspend":
            started.append((key, int(fields["delay"])))
        elif event in RESOLVED_EVENTS:
            resolution[key] = event
    counts = defaultdict(lambda: [0, 0])
    unresolved = []
    for key, delay in started:
        counts[delay][0] += 1
        outcome = resolution.get(key)
        if outcome == "resumed":
            counts[delay][1] += 1
        elif outcome is None:
            unresolved.append((key[0], key[1], delay, "hung or interrupted"))
        else:
            unresolved.append((key[0], key[1], delay, outcome))
    return counts, unresolved


def command_report(_options):
    path = log_path()
    if not path.exists():
        print(f"no log at {path}", file=sys.stderr)
        return 2
    counts, unresolved = parse_log(path)
    print("delay  started  resumed  unresolved")
    for delay in sorted(counts):
        started, resumed = counts[delay]
        print(f"{delay:>4} s  {started:>7}  {resumed:>7}  {started - resumed:>10}")
    for run_id, cycle, delay, why in unresolved:
        print(f"unresolved: run {run_id} cycle {cycle} delay {delay} s ({why})")
    return 0


def positive_int(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    commands = parser.add_subparsers(dest="command", required=True)
    run_parser = commands.add_parser("run")
    run_parser.add_argument("--delays", default=DEFAULT_DELAYS)
    run_parser.add_argument("--rounds", type=positive_int, default=6)
    run_parser.add_argument("--wake", choices=["rtc", "key"], default="rtc")
    run_parser.add_argument("--settle", type=int, default=20)
    run_parser.add_argument("--seed", type=int)
    run_parser.add_argument("--min-delay", type=int, default=15)
    run_parser.add_argument("--wait-extra", type=positive_int, default=180)
    run_parser.add_argument("--dry-run", action="store_true")
    run_parser.set_defaults(handler=command_run)
    report_parser = commands.add_parser("report")
    report_parser.set_defaults(handler=command_report)
    options = parser.parse_args()
    return options.handler(options)


if __name__ == "__main__":
    sys.exit(main())
