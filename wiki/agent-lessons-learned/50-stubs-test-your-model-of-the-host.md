# 50. A check with the host program stubbed tests your model of the host, not the host

_Last modified: 2026-10-27_

## Index entry

§50 in [agent-lessons-learned.md](../agent-lessons-learned.md)

## The lesson

Three files plug into programs this repo does not own: `carapace-desc.bash`
and `cod-desc.bash` are ble.sh advice around two other tools' completers, and
`carapace-completer-read-fix.bash` rewrites a function carapace generates.
Each had been checked, and each check passed. A real Tab press in an attached
ble.sh (2026-10-26, driven with terminal-puppeteer) found all three broken:

1. **The read-fix returned no completions.** It replaced `IFS=$'\001' read
   nospace data` with parameter expansions that split the other way round, so
   the completions landed in `nospace` and the flag in `data`. The 2026-08-24
   check counted `read: not a valid identifier` errors, which the fix did
   remove; a swapped split raises none. It also left out the newline the
   original `<<<` here-string added, which carapace's next lines (`unset
   COMPREPLY[-1]`) rely on.
2. **carapace's descriptions never reached the menu.** The advice began with
   `((ADVICE_EXIT==0)) || return 0`. The 2026-08-22 check stubbed ble.sh's
   functions and ran the advice with `ADVICE_EXIT=0`. The real
   `_carapace_completer` ends in `[[ "${COMPREPLY[*]}" == "" ]] && COMPREPLY=()`,
   so it returns 1 exactly when it has candidates, and the guard skipped every
   case that mattered.
3. **cod's table was gone when the advice ran.** The table was `declare -A` at
   the end of the file. The 2026-09-25 check sourced the file at top level,
   where that is a global. ble.sh sources it with `ble-import`, inside its own
   function, where `declare` is local; the advice then built an indexed array
   and every lookup became an arithmetic error on Tab.

What the three share: **the stub's inputs came from the author's model of the
caller, not from the caller.** `ADVICE_EXIT=0` was assumed. "Sourced at top
level" was assumed. "No `read` errors" was taken as the success criterion
because it was the symptom. A stub can only confirm that the code does what
you believed the host would ask of it, and the bug was in the belief.

What to do instead:

- When the code is an adapter into another program, run the real program at
  least once and read what it does (§25's rung, here for code that is not
  Nix). Here that is `just completion-live-test`, which presses Tab in an
  attached ble.sh for each of the three behaviours; against the previously
  deployed files it fails all three, each for its own reason.
- When a stub is still the right tool, take its inputs from a real run
  (`_carapace_completer`'s actual exit status, how `ble-import` actually loads
  a file) and say so in the test.
- Pick the success criterion from what the user sees (the candidate completes;
  the description shows), not from the error that prompted the work.
- A "confirmed" that names a count of errors instead of the behaviour is
  *evaluates* (§18) wearing a different label.

Fixed in PR #541. The live test is opt-in (it needs an installed ble.sh, cod's
per-user daemon, carapace and terminal-puppeteer, and takes ~30s), so nothing
in `just preflight` repeats it.
