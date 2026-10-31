# 53. A failure only CI shows is an environment difference

_Last modified: 2026-10-31_

## Index entry

§53 in [agent-lessons-learned.md](../agent-lessons-learned.md)

## The lesson

terminal-puppeteer's `main` had been red for days, and the first guess
(a half-submitted PR, then a lockfile) was wrong both times. The cause was two
differences between the author's machine and CI:

1. Two tests sent `clear`, which needs `$TERM`. CI sets none, so `clear`
   printed "TERM environment variable not set." and the screen kept its text.
2. A skip decorator (`skipUnless fish 4`) sat on the neighbouring class, so
   the class that needed fish had no skip and the nix build, which has no fish,
   errored on it.

Both passed locally for days because the machine had a `TERM` and a fish. The
log named each cause in one line. Both reproduced in one command once the
environment was removed: `env -u TERM python3 -m unittest ...`, and the suite
run on a `PATH` without fish.

## The rule

When a check fails only in CI, read the failing job's log for the line that
names the cause, then take the thing away locally (unset the variable, drop the
tool from `PATH`, run in the build sandbox) and watch it fail the same way
before changing anything. Fix it, and watch the same command pass. Guessing at
a cause from the PR list or the lockfile costs more than reading the log.

## Related

§3 (when a tool contradicts you, check your own assumption), §51 (a reported
cause is a hypothesis), §1 (success is not tested).
