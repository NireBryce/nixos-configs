# 20. A pipeline reports the exit status of its last command

_Last modified: 2026-10-30_

## Index entry

§20 in [agent-lessons-learned.md](../agent-lessons-learned.md)

## The lesson

`just check 2>&1 | tail -60` exited 0 and I reported the check as passing. `just`
had exited 1; the failure was in the text `tail` printed, and I read past it
because the status said otherwise. `set -o pipefail`, or do not pipe.

**A status and the text above it are two claims, and when they disagree the text
is usually the honest one.**

## Addendum (2026-10-30): the same mistake without a pipe

A script that ran `just preflight >/dev/null 2>&1; echo "rc=$?"` and then, on
the next lines, committed, pushed and opened a PR reported `rc=1` and carried
on, because nothing tied the later steps to the status. The PR body claimed
preflight passed. Read the status before the first step that goes outward
(commit, push, PR body), or chain with `&&`, or `set -e`; a status printed and
ignored is no better than one masked by a pipe.
