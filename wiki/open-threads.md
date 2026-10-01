# Open threads

_Last modified: 2026-10-01_

The repo's loose ends (todos left in code, upstream bugs found here,
undecided design questions) are GitHub issues on this repo, not entries on
this page. Until 2026-10-01 this page listed them as prose, and most of its
edits were status flips; the open ones moved to issues that day. What stays
here is what isn't a tracked item: where to look, and the rule about
third-party write-ups.

> **Condensed version:**
> [open-threads-for-agents.md](open-threads-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [Where the threads are](#where-the-threads-are)
- [Upstream write-ups are not filed upstream](#upstream-write-ups-are-not-filed-upstream)
- [Not tracked, on purpose](#not-tracked-on-purpose)

## Where the threads are

```sh
gh issue list --repo NireBryce/nixos-configs                     # everything open
gh issue list --repo NireBryce/nixos-configs --label upstream    # bug lives in a third-party project
gh issue list --repo NireBryce/nixos-configs --label question    # undecided, waiting on the user
gh issue list --repo NireBryce/nixos-configs --label pending-setup  # one-time step on a live service
```

**Before starting work on a thread, or investigating a symptom that might
already be one:** `just threads "<keywords>"` searches the issues and
greps `wiki/` and `_loose-ends/bugs-pending-submission/` in one pass
(skill `investigate-bug`). This exists because a ble.sh/carapace bug was
rediscovered from scratch once, at real cost, before it was tracked
([#72](https://github.com/NireBryce/nixos-configs/issues/72)).

The `pending-setup` label is the fleet-side counterpart, explained on
[homelab/pending-setup.md](homelab/pending-setup.md).

## Upstream write-ups are not filed upstream

`_loose-ends/bugs-pending-submission/` holds bug reports written up against
third-party projects (nixpkgs, `amd-debug-tools`, Jovian-NixOS), each with
an `upstream`-labelled issue here that tracks it (#TBD-upstream-vscode-ripgrep,
#TBD-upstream-amd-s2idle, #TBD-upstream-jovian-iommu). **Neither the file
nor the issue is a reason to file it upstream**: per `AGENTS.md`, filing
outside `NireBryce/nixos-configs` happens only when the user says so
explicitly, in those words, for that specific report — not as a
housekeeping pass over this list or the label. Tracking one here is not
working it.

## Not tracked, on purpose

Notes that have no "done when", so an issue would only sit open:

- Idea placeholders:
  [`../flake/scripts/script-wishlist.md`](<../flake/scripts/script-wishlist.md>)
  (bare headings) and the "things to look into" list ending
  [`../flake/doc/notes-and-fixes.md`](<../flake/doc/notes-and-fixes.md>).
- Self-hosted booking (Easy!Appointments vs LibreBooking) was compared
  2026-08-24 and not pursued: neither is in nixpkgs or has a NixOS module,
  and both are PHP apps wanting a writable install dir. The write-up is
  in git history (`claude cave/`, removed 2026-09-01).
- `ignore/` and `flake/!IGNORE-maybe-useful-chunks/` hold retired
  experiments, each with a README saying why it didn't work. Anything
  under an `ignore`/`IGNORE`-prefixed path is not indexed anywhere on
  purpose.
