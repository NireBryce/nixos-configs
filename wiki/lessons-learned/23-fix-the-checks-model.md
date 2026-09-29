# 23. When a check fires on new work, fix its model before reaching for the flag

_Last modified: 2026-09-29_

§23 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §23's full account.

Splitting out `kde-base.nix` made `just modules` report it as an orphan.
`modules.py` has an `ORPHAN-OK` escape hatch for exactly that complaint.

Using it would have been wrong. The module *is* imported, through a `let`-bound
`config.flake.modules.nixos.kde-base` — a third import form the checker did not
model, and one **the repo already used**. The check was right to fire and wrong
about the reason; the flag would have silenced a true report and left the blind
spot for the next person.

**"This check is wrong" and "this check is incomplete" present identically and
call for opposite responses.** Per §1, the widened checker was then run against
a tree with a deliberately dead module, to confirm it still reports one.
