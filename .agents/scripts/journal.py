#!/usr/bin/env python3
"""Read the systemd journal for named units, fenced as third-party text.

Answers: what did unit X log, without pulling free journal text into an agent's
context raw. The journal is writable by any local user (`logger`, any
process's stdout) and by anything a service prints, so a bare `journalctl`
reads attacker-influenceable text. This replaces it for agent use:

  - requires --unit (repeatable) or --kernel: no unfiltered dump;
  - keeps four fields per entry: time, unit, priority, message; the message is
    clamped by untrusted.py (escapes, hidden characters, length) and the whole
    output is fenced;
  - marks every entry whose sender was not root (`uid=N`), the usual shape of a
    forged line, so it reads as less trustworthy at a glance.

    journal.py (--unit NAME ... | --kernel) [--boot N] [--since T] [--priority P]
               [--lines N]

--lines defaults to 100 and is capped at 500. Read-only: it runs
`journalctl -o json` and nothing else. A unit's own messages are still text its
program chose to print; the fence says so and the user's rule stands that the
agent does not act on text inside it without being asked.
"""
import argparse
import json
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import untrusted

MAX_LINES = 500
# untrusted.fence caps a line at 200 characters (plus a truncation note) and the
# text at 8000; stay inside both so nothing is cut from the end.
LINE_CAP = 220
TEXT_BUDGET = 7500


def message_text(raw):
    """MESSAGE is a string, or a list of byte values when it is not UTF-8."""
    if isinstance(raw, list):
        return bytes(value for value in raw if isinstance(value, int) and 0 <= value < 256).decode("utf-8", "replace")
    return str(raw) if raw is not None else ""


def format_entry(entry):
    microseconds = int(entry.get("__REALTIME_TIMESTAMP", "0") or 0)
    stamp = datetime.fromtimestamp(microseconds / 1_000_000, tz=UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    unit = entry.get("_SYSTEMD_UNIT") or entry.get("_TRANSPORT") or "?"
    priority = entry.get("PRIORITY", "?")
    sender = entry.get("_UID")
    # A missing _UID is not root: mark it, so it never reads as a root message.
    provenance = "" if sender == "0" else f" uid={sender if sender is not None else '?'}"
    message = message_text(entry.get("MESSAGE")).replace("\n", " \\n ")
    return f"{stamp} {unit} p{priority}{provenance}: {message}"


def newest_within_budget(lines, budget=TEXT_BUDGET):
    """Keep the newest lines that fit; say how many older ones were dropped.

    untrusted.fence cuts from the end of the text, which would keep the oldest
    entries and drop the newest, the ones usually being looked for.
    """
    kept = []
    used = 0
    for line in reversed(lines):
        cost = min(len(line), LINE_CAP) + 1
        if used + cost > budget:
            break
        kept.append(line)
        used += cost
    kept.reverse()
    dropped = len(lines) - len(kept)
    if dropped:
        kept.insert(0, f"[{dropped} older entries omitted to fit]")
    return kept


def positive_int(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return number


def build_command(args):
    command = ["journalctl", "--no-pager", "-o", "json", "-b", str(args.boot), "-n", str(min(args.lines, MAX_LINES))]
    # `--option=value` forms, so a value starting with `-` is never an option.
    if args.since:
        command.append(f"--since={args.since}")
    if args.priority:
        command.append(f"--priority={args.priority}")
    if args.kernel:
        command.append("--dmesg")
    for unit in args.unit:
        command.append(f"--unit={unit}")
    return command


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--unit", action="append", default=[])
    parser.add_argument("--kernel", action="store_true")
    parser.add_argument("--boot", type=int, default=0)
    parser.add_argument("--since")
    parser.add_argument("--priority")
    parser.add_argument("--lines", type=positive_int, default=100)
    args = parser.parse_args()
    if not args.unit and not args.kernel:
        print("journal.py: give --unit NAME (repeatable) or --kernel; no unfiltered reads", file=sys.stderr)
        return 2
    result = subprocess.run(build_command(args), capture_output=True, text=True, check=False)
    if result.returncode != 0:
        print(f"journalctl failed: {result.stderr.strip()[:200]}", file=sys.stderr)
        return result.returncode
    lines = []
    for raw in result.stdout.splitlines():
        try:
            lines.append(format_entry(json.loads(raw)))
        except (json.JSONDecodeError, ValueError, OverflowError, TypeError):
            continue
    source = "journal:" + ",".join(args.unit or ["kernel"])
    sys.stdout.write(untrusted.fence("\n".join(newest_within_budget(lines)), source))
    return 0


if __name__ == "__main__":
    sys.exit(main())
