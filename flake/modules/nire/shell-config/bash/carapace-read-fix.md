# The carapace read-corruption fix, and how to undo it

> **Written by Claude Code.** A working note, not documentation.

## What's wrong

Typing at a real interactive terminal with carapace as the active
completer produces a stray `-bash: read: `': not a valid identifier` line
alongside an otherwise-correct completion menu, on both explicit Tab and
ble.sh's inline auto-complete-as-you-type. Cosmetic-looking but not
actually cosmetic — under the hood, one `read` call inside carapace's own
generated `_carapace_completer` is intermittently getting its arguments
corrupted.

**Not this repo's bug.** ble.sh's own auto-complete machinery installs a
cancellation safety net while any registered completer runs, checked every
`bleopt_complete_polling_cycle` reads (50 by default) against whether the
user is still typing — true very often at normal typing speed, not a rare
condition. When that check catches carapace's own
`IFS='<SOH byte>' read -r -d '' nospace data <<< "${data}"` line mid-flight,
the args come back split character-by-character instead of into the two
variable names, which is what produces the error. Confirmed independently
twice (2026-08-22 and 2026-08-24) that this happens with carapace's stock
completer alone, no advice or config from this repo involved.

Full diagnosis: [`wiki/categories/shell-config/blesh.md`](../../../../../wiki/categories/shell-config/blesh.md#bug-spurious-read--not-a-valid-identifier-on-tab--auto-complete),
[`claude cave/lessons-learned.md`](<../../../../../claude cave/lessons-learned.md>) #39,
[issue #72](https://github.com/NireBryce/nixos-configs/issues/72).

## What the fix does

[`carapace-completer-read-fix.bash`](./carapace-completer-read-fix.bash)
patches `_carapace_completer`'s body — via `declare -f` plus a textual
substitution — replacing that one `read` call with pure parameter
expansion (`nospace=${data##*$sep}; data=${data%$sep*}`, `$sep` the same
real separator byte). No `read`, nothing for ble.sh's global override to
catch, same result.

It has a built-in tripwire: if carapace ever changes its generated
template so the exact line being matched no longer appears, the fix
doesn't silently do nothing — it prints a loud warning to stderr on every
new shell (`expected line not found in _carapace_completer ...`). Seeing
that warning means the fix has stopped applying, not that anything is
broken; see "How to undo" below for what to do about it.

## Where it's wired in

`bash.nix`'s `initExtra`, immediately after
`source <(carapace _carapace bash)` and before `carapace-desc.bash`'s
advice wraps the same function. Order matters both ways: this fix needs
`_carapace_completer` to already exist (so it must come after the carapace
source line), and it needs to run before the advice wrap so the advice
ends up wrapping the *patched* version, not the original.

## Status as of 2026-08-24

**Confirmed, through a real `just switch`.** In the tree, evaluates
correctly (`just modules` clean, renders into `programs.bash.initExtra` as
expected), landed via [PR #73](https://github.com/NireBryce/nixos-configs/pull/73),
and switched on `nire-cube` (generation 10, current). Re-verified live
against the switched host with
[`terminal-puppeteer`](https://github.com/NireBryce/terminal-puppeteer) —
several passes of the original repro, zero errors, plus a check that the
fix's own tripwire warning doesn't fire (confirming the substitution is
actually applying, not silently skipping). See `lessons-learned.md` #39
and [issue #72](https://github.com/NireBryce/nixos-configs/issues/72) for
the full account.

## How to undo

Tracked as [issue #75](https://github.com/NireBryce/nixos-configs/issues/75)
— check there first, it may already say more than this section does by
the time you're reading it. If this ever needs backing out — carapace
fixes the underlying bug upstream, ble.sh changes how its cancellation
path works, or the fix turns out to cause some problem of its own:

1. Remove the `source ${carapaceCompleterReadFix}` line from `bash.nix`'s
   `initExtra` (the block right after `source <(carapace _carapace bash)`).
2. Remove the `carapaceCompleterReadFix` binding from `bash.nix`'s `let`
   block (the `pkgs.writeText "carapace-completer-read-fix.bash" ...` one).
3. Delete `carapace-completer-read-fix.bash` (this directory) and this file.
4. `just switch` (or `just build` first to check it still evaluates) on
   whichever host you're testing.

**Before removing it because carapace shipped a new version**: re-run the
repro rather than assuming a version bump fixed it. `terminal-puppeteer
--ssh <host> 'git co' TAB CTRL-C` a few times is the same check that found
this in the first place — a version bump changing carapace's generated
template is exactly what would also make this fix's own tripwire warning
fire (see "What the fix does" above), which is your actual signal to look
again, not silence.

If the tripwire warning fires because carapace changed its template but
the underlying ble.sh interaction is still there, the fix needs updating to
match the new template rather than removing. Check
`declare -f _carapace_completer | grep -A1 "read -r -d"` in a real
interactive shell (not a bare `carapace _carapace bash` — see
`carapace.md`'s own note on why those two can render the separator byte
differently) to see the current form, and update the search string in
`carapace-completer-read-fix.bash` to match. `terminal-puppeteer`'s own
`NOTES.md` covers the byte-invisibility trap that made this fiddly the
first time around — read that before trusting what the terminal shows you
for the new line.
