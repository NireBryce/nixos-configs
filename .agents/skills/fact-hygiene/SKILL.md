---
name: fact-hygiene
description: Keeps facts, dated snapshots, cross-references and copied values from going stale when you write them.
when_to_use: Writing a claim about live state or an external system, a status as of a date, a comment asserting something about other modules or hosts, or a count or version copied from another file.
---

# Writing facts, dated status, and cross-references without them rotting silently

## Applies to

1. **A specific, checkable fact about an external system** (host, `ts-hive`,
   vendor UI, hardware not in front of you): a path, share or volume name,
   permission, version, or "confirmed working", stated with more confidence
   than you observed this session.
2. **A "status as of `<date>`" snapshot** asserting current mutable state
   (secret set? host switched? service reachable). The date reads as freshly
   checked, and nothing re-verifies it.
3. **A cross-reference to something else in this repo** (host, module, option,
   secret) in a comment, stated as a currently true fact ("X and Y both do
   Z"). A later rename or removal cannot know the comment exists; `just
   modules` (module renames) and `wiki-sync` (wiki claims) do not check
   plain-English `.nix` comment mentions.
4. **A derived fact that a command or the cited file already answers**: a
   count of files, modules, subdirectories, hosts, recipes or skills ("all four
   files", "228 files"); a line count; a live-state version (kernel, Mesa,
   package); a config value (timer, retention, size, timeout) copied from a
   file the doc links. Nothing re-derives it when the source changes. Found
   2026-10-22: a file count already off from the module graph, and about 60
   more sites.

**Not this skill; write freely:**

- Design rationale (why, trade-offs, rejected alternatives).
- **Event dates** ("on `<date>` X happened/was decided/failed"). A past event
  cannot go stale. Test: does the sentence describe something that happened,
  or assert something currently true?
- Plans, hypotheses and open questions, labeled as such. The failure is a
  hypothesis or stale snapshot stated as confirmed current fact.
- Plain comments describing what the code in front of you does.

## Why (all three traps: once phrased as settled, it stops looking checkable and gets copied)

Once a claim is phrased as settled, it stops looking checkable and gets
copied. Three incidents:

- **Cat 2, 2026-09-03 (`216a5ae7`):** `wiki/homelab/pending-setup.md` item 4,
  the `wiki/homelab/backup-runbook.md` intro, and
  `wiki/config-structure/categories/backup.md` "What isn't done yet" each said
  the two restic sops secrets had no value, days after both were set. Grepping
  `secrets.yaml` exposed it by accident. AGENTS.md's State section is the
  narrower version of this rule.
- **Cat 1, same day:** the NAS's `restic-backup` share was called "dedicated to
  this module", inherited from an NFS-era comment about a different mount. The
  claim spread into the `restic.nix` header,
  `wiki/config-structure/categories/backup.md` and
  `wiki/homelab/backup-runbook.md` until a snapshot-schedule screenshot showed
  the repo under share `homes`. A "real path" also fused a volume label from
  one old comment with a path seen over ssh (`/share/homes/nire`); no
  observation showed both.
- **Cat 3, same sweep:** four passing comments still named a host removed a week
  earlier (other removed-host references had explicit removal notes). The hosts,
  files and comments are in `216a5ae7`'s diff; they were deleted, not
  rewritten.

## The rule

- **Cat 1:** state only what you observed this session by a named method
  (command output, screenshot, file read). Give everything else (inferred from
  a similar system, carried over, assumed common case) a qualifier
  (`UNVERIFIED`, `not confirmed live`, `assumed from ...`) in the same
  sentence, not in a separate caveat paragraph that a trim can drop.
- **Cat 2:** a date records when someone last checked; it does not guarantee
  freshness. Re-derive anything checkable now. If you cannot, write "last
  checked `<date>`, unconfirmed since".
- **Cat 3:** a name in a comment is a live pointer that can dangle; see #7.
- **Cat 4:** do not record it. Replace it with a pointer (`the modules under
  X`, the file that sets the value, the command that prints it), or name the
  items and drop the number. Keep a number only when it is the rule itself
  ("1,000 words"), part of a dated incident or experiment record, a PR, issue
  or commit reference, a config pin with a removal condition (`confirmedOn`),
  the reason a value was chosen, or an interface a user types (a port, a
  lockout window). Counts inside `wiki_gen` generated blocks regenerate and are
  fine. `factcheck docrefs` flags the bare count-of-files shape; the rest takes
  judgment.

## Preventing it

1. For each specific noun in a why/history sentence (path, share or volume,
   permission, version), name the command or artifact from this session that
   showed it. Otherwise mark it inferred inline or omit it.
2. Do not fuse two separately true facts into one unobserved claim (a label from
   one comment plus a path from another). A gap between true statements is a
   hole, not a bridge.
3. Before copying forward a "Status as of" line, check whether the fact could
   have changed. If you can check now (file, command), check instead of
   trusting the date.
4. If you cannot check because you lack access (NAS admin UI, decrypt key,
   other hardware), do not guess and do not stamp today's date. Write the open
   question down, or ask.
5. Precision or a date beyond what you checked is a liability: the vaguer true
   (or explicitly stale) statement outlives the sharper false one.
6. **Condensing into a `-for-agents.md` sibling strips qualifiers first, as
   hedging.** `UNVERIFIED`, `not confirmed live`, `assumed from ...`, `last
   checked <date>, unconfirmed since` and `not exercised` state how confident
   the claim is; they are not narration. Carry them verbatim. If there is no
   room for both claim and qualifier, drop the claim.
7. **When removing or renaming a name other code might mention** (host, module,
   secret, option), grep the exact name across `flake/modules`, not just
   `wiki/` or the touched files. A mention without "since removed" or "since
   renamed" shows it was missed.

## When a claim turns out wrong

1. Run `grep -rn "<old claim/path/name>" wiki/ flake/`. Dated-sounding claims
   get copied more than obviously uncertain ones.
2. Fix every copy in the same change (`wiki-sync` mechanical half) and correct
   the confidence level as well as the content: write a verified current fact,
   or an explicit `UNVERIFIED`/`unconfirmed since <date>`.
3. If a comment recorded why the wrong claim was believed, keep it (repo
   convention: a bug recorded in a comment stays).

## See also

- `wiki-sync` — finds and fixes every `wiki/` page (siblings included) a stale
  fact reached; it covers `wiki/` only, and cat 3 covers `flake/` comments.
- `wiki/meta/styleguide.md` "Two audiences per page": its cut-list item ("who
  confirmed it and when") and #6 differ. Who or how it was verified is
  narration and goes; whether it was verified at all is a qualifier and stays.
- `AGENTS.md` "State" — the narrower cat-2 rule for switch/boot status.
- `restic.nix` header, `wiki/config-structure/categories/backup.md`,
  `wiki/homelab/backup-runbook.md`, `wiki/homelab/pending-setup.md` — the cat
  1/2 pages. The `UNVERIFIED` markers added in `216a5ae7` have mostly been
  resolved and removed since, so its diff holds the before/after.
- `podman.nix`, `hosts.nix`, `invariants.nix` — correct style: explicit removal
  notes ("lego removed the same day", "were both removed 2026-08-27", "since
  removed"). `category-collector.nix`, once named as a fourth example, was
  retired 2026-10-16.
- skill `git-archaeology` — find the commit behind a date or hash when the file
  moved; an empty path-scoped log usually means a rename (hit 2026-09-15
  verifying this file's examples).
