# 20. A pipeline reports the exit status of its last command

_Last modified: 2026-09-29_

§20 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §20's full account.

`just check 2>&1 | tail -60` exited 0 and I reported the check as passing. `just`
had exited 1; the failure was in the text `tail` printed, and I read past it
because the status said otherwise. `set -o pipefail`, or do not pipe.

**A status and the text above it are two claims, and when they disagree the text
is usually the honest one.**
