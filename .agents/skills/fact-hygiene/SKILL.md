---
name: fact-hygiene
description: How to write a specific fact, a dated status snapshot, or a cross-reference to something elsewhere in this repo without it quietly rotting into a false claim.
---

# Writing facts, dated status, and cross-references without them rotting silently

## Applies to

1. **Specific checkable fact about an external system** (host, QNAP, vendor UI, hardware not in front of you): path, share/volume name, permission, version, "confirmed working" — stated with more confidence than observed this session.
2. **"Status as of `<date>`" snapshot** asserting current mutable state (secret set? host switched? service reachable). The date reads as freshly checked; nothing re-verifies it.
3. **Cross-reference to something else in this repo** (host, module, option, secret) in a comment as a currently-true fact ("X and Y both do Z"). A later unrelated rename/removal can't know the comment exists; `just modules` (module renames) and `wiki-sync` (wiki claims) don't check plain-English `.nix` comment mentions.

**Not this skill; write freely:**

- Design rationale (why, trade-offs, rejected alternatives).
- **Event dates** ("on `<date>` X happened/was decided/failed") — a past event can't go stale. Tell: does the sentence describe something that happened, or assert something currently true?
- Plans, hypotheses, open questions, labeled as such (a hypothesis or stale snapshot stated as confirmed current fact is the failure).
- Plain comments describing what the code in front of you does.

## Why (all three traps: once phrased as settled, it stops looking checkable and gets copied)

- **Cat 2, 2026-09-03 (`216a5ae7`):** `wiki/homelab/pending-setup.md` item 4, `wiki/homelab/backup-runbook.md` intro, and `wiki/categories/backup.md` "What isn't done yet" each said the two restic sops secrets had no value, days after both were set. Found by accident grepping `secrets.yaml`. AGENTS.md's State section is the narrower version of this rule.
- **Cat 1, same day:** QNAP `restic-backup` share called "dedicated to this module" — inherited from an NFS-era comment about a different mount — spread into `restic.nix` header, `wiki/categories/backup.md`, `wiki/homelab/backup-runbook.md` until a Snapshot Manager screenshot showed the repo under share `homes`. Also `real path /share/ZFS19_DATA/homes/nire` fused a volume label from one old comment with a path seen over ssh (`/share/homes/nire`); no observation said both.
- **Cat 3, same sweep:** four passing comments still named a host removed a week earlier (other removed-host references had explicit removal notes). Hosts/files/comments are in `216a5ae7`'s diff; deleted, not rewritten.

## The rule

- **Cat 1:** state only what you watched this session by a named method (command output, screenshot, file read). Everything else (inferred from a similar system, carried over, assumed common case) gets a qualifier (`UNVERIFIED`, `not confirmed live`, `assumed from ...`) **in the same sentence**, not a separate caveat paragraph a trim can drop.
- **Cat 2:** a date is when someone last checked, not a freshness guarantee. Re-derive anything checkable now; if not, write "last checked `<date>`, unconfirmed since".
- **Cat 3:** a name in a comment is a live pointer that can dangle; see #7.

## Preventing it

1. For each specific noun in a why/history sentence (path, share/volume, permission, version), name the command/artifact from *this* session that showed it. Otherwise mark it inferred inline or omit it.
2. Don't fuse two separately-true facts into one never-observed claim (label from one comment + path from another). A gap between true statements is a hole, not a bridge.
3. Before copying forward a "Status as of" line, check whether the fact could have changed; if checkable now (file, command), check instead of trusting the date.
4. Can't check without access you lack (NAS admin UI, decrypt key, other hardware): don't guess, don't stamp today's date. Write the open question down, or ask.
5. Precision or a date beyond what you checked is a liability; the vaguer true (or explicitly-stale) statement outlives the sharper false one.
6. **Condensing into a `-for-agents.md` sibling strips qualifiers first, as hedging.** `UNVERIFIED`, `not confirmed live`, `assumed from ...`, `last checked <date>, unconfirmed since`, `not exercised` are facts about the claim's confidence, not narration. Carry them verbatim; if there's no room for claim *and* qualifier, drop the claim.
7. **Removing/renaming a name other code might mention** (host, module, secret, option): grep the exact name across `flake/modules`, not just `wiki/` or the touched files. A mention lacking "since removed"/"since renamed" is the tell it was missed.

## When a claim turns out wrong

1. `grep -rn "<old claim/path/name>" wiki/ flake/` — dated-sounding claims get copied more than obviously-uncertain ones.
2. Fix every copy in the same change (`wiki-sync` mechanical half) and correct the *confidence level*, not just content: verified current fact, or explicit `UNVERIFIED`/`unconfirmed since <date>`.
3. If a comment recorded *why* the wrong claim was believed, keep it (repo convention: a bug recorded in a comment stays).

## See also

- `wiki-sync` — finds/fixes every `wiki/` page (siblings included) a stale fact reached; `wiki/` only, cat 3 covers `flake/` comments.
- `wiki/styleguide.md` "Two audiences per page": its cut-list item ("who confirmed it and when") and #6 differ — *who/how verified* is narration and goes; *whether verified at all* is a qualifier and stays.
- `AGENTS.md` "State" — narrower cat-2 rule for switch/boot status.
- `restic.nix` header, `wiki/categories/backup.md`, `wiki/homelab/backup-runbook.md`, `wiki/homelab/pending-setup.md` — cat 1/2 worked examples with `UNVERIFIED` markers and corrected dates.
- `podman.nix`, `hosts.nix`, `invariants.nix` — correct style: explicit removal notes ("lego removed the same day", "were both removed 2026-08-27", "since removed"). `category-collector.nix`, once named as a fourth example, holds no such comment today.
- skill `git-archaeology` — find the commit behind a date/hash when the file moved; an empty path-scoped log usually means a rename (hit 2026-09-15 verifying this file's examples).
