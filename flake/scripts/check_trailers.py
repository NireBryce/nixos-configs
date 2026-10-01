#!/usr/bin/env python3
"""Fail when a commit in a range carries a Claude Co-Authored-By trailer
that is not exactly `Co-Authored-By: Claude`.

AGENTS.md's convention: the trailer names the agent, no model name, no
email -- an agent cannot verify which model is executing it, and the
harness's own system prompt tells it to write `Claude <model> <email>`.
`.githooks/commit-msg` rewrites that shape at commit time, but only in a
clone that ran `just install-hooks`, and wrong trailers kept landing from
clones that had not (two `Claude Sonnet 5 <noreply@anthropic.com>` in
2026-09 alone). This is the check that does not depend on the clone: CI
runs it over a PR's own commits.

The match mirrors commit-msg's pattern -- `Claude`, then optionally a
model name and/or an `<email>` -- with the key matched case-insensitively
(git treats trailer keys that way; the hook's grep does not, so this is
strictly broader). Only trailers naming Claude are judged. Any other
agent's name-only trailer (`Co-Authored-By: ZCode`, `opencode`) passes:
no check can know which agent wrote a commit, so their form stays a
write-time rule, as AGENTS.md says.

Range, not history: the log holds over 200 wrong Claude trailers
(2026-09-29) that AGENTS.md says stay as they are, so this is only ever
pointed at the commits under review -- in CI, `HEAD^1..HEAD^2` of the
PR merge ref (check.yml says why that and not the event's base/head
SHAs).

Usage: check_trailers.py <rev-range>. Exit 0 clean, 1 on a finding, 2 on
a git error. Pure stdlib plus git; fixture-tested by
test_check_trailers.py (`just trailers-test`, in preflight).
"""
import re
import subprocess
import sys

CANONICAL = "Co-Authored-By: Claude"
# commit-msg's ERE, translated:
# ^Co-Authored-By:[[:space:]]+Claude([[:space:]]+[^<]*)?([[:space:]]*<[^>]*>)?[[:space:]]*$
PATTERN = re.compile(
    r"^(?i:co-authored-by):\s+Claude(\s+[^<]*)?(\s*<[^>]*>)?\s*$")


def bad_trailers(message):
    """Lines of `message` that are a Claude co-author trailer in any form
    other than the canonical one."""
    return [line for line in message.splitlines()
            if PATTERN.match(line) and line != CANONICAL]


def commits(rev_range):
    """(sha, subject, full message) for every commit in the range, merges
    included -- a merge commit on a PR branch is that PR's own too."""
    out = subprocess.run(
        ["git", "log", "--format=%H%x00%s%x00%B%x1e", rev_range],
        capture_output=True, text=True)
    if out.returncode != 0:
        sys.stderr.write(out.stderr)
        sys.exit(2)
    for record in out.stdout.split("\x1e"):
        record = record.lstrip("\n")
        if record:
            sha, subject, body = record.split("\x00", 2)
            yield sha, subject, body


def main(argv):
    if len(argv) != 2:
        sys.exit("usage: check_trailers.py <rev-range>")
    found, count = [], 0
    for sha, subject, body in commits(argv[1]):
        count += 1
        for line in bad_trailers(body):
            found.append((sha, subject, line))
    if found:
        print("Co-Authored-By trailer not in the canonical form "
              f"`{CANONICAL}` (no model name, no email):", file=sys.stderr)
        for sha, subject, line in found:
            print(f"  {sha[:12]} {subject}\n      {line}", file=sys.stderr)
        print("Reword those commits (amend the tip, or rebuild the branch) "
              "and force-push the PR branch. `just install-hooks` makes "
              ".githooks/commit-msg fix this at commit time.",
              file=sys.stderr)
        return 1
    print(f"trailers ok: {count} commit(s) in {argv[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
