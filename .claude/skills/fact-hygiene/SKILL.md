---
name: fact-hygiene
description: How to write a specific fact, a dated status snapshot, or a cross-reference to something elsewhere in this repo without it quietly rotting into a false claim.
---

# Writing facts, dated status, and cross-references without them rotting silently

## Applies to

Three related but distinct things:

1. **A specific, checkable fact about an external system** (a real host, a
   QNAP, a vendor UI, hardware you're not looking at right now) — a path,
   a share/volume name, a permission, a version, "confirmed working" —
   stated with more confidence than what was actually observed this
   session.
2. **A "Status as of `<date>`" / "as of `<date>`" snapshot line** —
   asserting the *current* state of something mutable (is a secret set,
   is a host switched, is a service reachable), where the date makes it
   look freshly checked but nothing re-verifies it as time passes.
3. **A cross-reference to something else in this repo** — a host name, a
   module, an option, a secret — mentioned in a comment as a currently-true
   fact ("X and Y both do Z"), where the thing referenced can be renamed
   or removed by a *later, unrelated* change that has no reason to know
   this comment exists. Unlike a module rename (`just modules` catches a
   name mismatch mechanically) or a wiki claim (`wiki-sync`'s job),
   nothing checks a plain-English mention in a `.nix` comment against the
   thing it names.

**Not this skill, write these freely and generously — this is most of
what a good comment or history section actually is:**

- Design rationale — *why* a choice was made, trade-offs weighed, an
  alternative rejected. That's the agent's own reasoning, not a claim
  about external reality; it doesn't need "I watched this happen."
- **Event dates** — *on `<date>`, X happened/was decided/was tried and
  failed.* A past event is fixed the moment it happens; it can't go
  stale, and `trim-docs`'s "Keep" list plus every dated
  `lessons-learned.md` entry depend on writing these richly. This is the
  opposite of category 2 above — the tell is whether the sentence
  describes something that happened, or asserts something that is
  currently true.
- Plans, hypotheses, and open questions — clearly labeled as such (a
  hypothesis stated as a hypothesis is not the failure mode below; a
  hypothesis, or a stale status snapshot, stated as a confirmed current
  fact is).
- A plain comment describing what the code in front of you does.

## Why this exists

**The dated-snapshot trap (category 2) — the one that actually bit
repeatedly, 2026-09-03.** `wiki/homelab/pending-setup.md` item 4,
`wiki/homelab/backup-runbook.md`'s intro, and `wiki/categories/backup.md`'s
"What isn't done yet" section *each independently* carried a "Status as of
2026-08-24" / "as of 2026-08-31" line stating the two restic sops secrets
had no value in the tree. All three were wrong — both secrets had been set
on 2026-08-30 and 2026-08-31 — and all three had a date attached that made
them read as recently verified. None of them was; the date recorded when
the line was *written*, not when it was last *true*. The staleness was
caught by accident, grepping `secrets.yaml` for an unrelated reason, not
by anyone re-checking the dated claims themselves. This is a direct
extension of AGENTS.md's State section (switch/boot state is deliberately
never recorded because it rots this exact way) — except that rule was
scoped to switch/boot status specifically, and the same rot hit three
other unrelated docs the same day. The mechanism generalizes past what
AGENTS.md currently names.

**The unconfirmed-specific trap (category 1), same session.** An early
comment called the QNAP's `restic-backup` share "dedicated to this
module" — never independently checked, carried forward from an even
earlier NFS-era comment about a differently-named mount point — and got
copied into `restic.nix`'s header, `wiki/categories/backup.md`, and
`wiki/homelab/backup-runbook.md` before a screenshot of the QNAP's actual
Snapshot Manager showed the repo really lived under a share called
`homes`. Separately, a path was written as directly confirmed ("real path
`/share/ZFS19_DATA/homes/nire`") when only `/share/homes/nire` had
actually been observed over ssh — `ZFS19_DATA` was inferred from a
different, older comment and stated with the same confidence as the part
that was checked.

**The cross-reference trap (category 3), found sweeping the tree for the
above two, same day.** `nire-lego` was removed 2026-08-27
(`wiki/history.md`). Four `.nix` comments elsewhere — `forgejo.nix` (two
spots), `golink.nix`, `bash.nix` — still named it in present tense
("durandal/tenacity/lego get [the `/root` wipe]", "no desktop imported —
tenacity, lego") a week later, because the commit that removed `lego`
touched `hosts.nix` and the modules `lego` itself had imported, not these
four unrelated files that merely *mentioned* it in passing. Contrast with
every other removed-host reference in the tree (`podman.nix`, `hosts.nix`,
`invariants.nix`, `category-collector.nix`), which all correctly say
"since removed" — proof this is preventable, not inherent to mentioning a
host name at all.

All three traps share a root cause: once something is phrased as settled
— narrated history, a dated status line, or a passing mention of another
part of the tree — it stops looking like something that needs checking,
and gets copied or left standing long after the thing it describes has
changed.

## The rule

**Category 1** (a specific external fact): state only what you watched
happen, in this session, by a named method — a command's actual output, a
screenshot, a file you read. Everything else — inferred from a similar
system, carried over from an earlier comment, assumed because it's the
common case — gets an explicit qualifier (`UNVERIFIED`, `not confirmed
live`, `assumed from ...`) *in the same sentence*, not hedged once in a
separate caveat paragraph a later trim or copy can drop while the
confident sentence survives.

**Category 2** (a dated status line): a date on a claim about current
state is not a freshness guarantee — it's the date someone last checked,
which starts going stale the instant anything changes. Before writing or
trusting a "Status as of `<date>`" line for anything checkable in the
current session, re-derive it rather than repeat it. If it genuinely can't
be re-checked right now, say so explicitly ("last checked `<date>`,
unconfirmed since") rather than letting the date alone imply currency.

**Category 3** (a cross-reference): a name written into a comment as a
durable fact ("hosts A/B/C do X") is a live pointer, not prose that stays
true on its own — a later, unrelated change can invalidate it the way a
symlink can dangle, with nothing watching for the break. See "Preventing
it" #6 for the concrete grep.

## Preventing it

1. **For each specific noun in a "why"/"history" sentence** — a path, a
   share or volume name, a permission, a version — name the exact command
   or artifact that showed you this, from *this* session. If you can't,
   it's inferred: say so inline, or leave the detail out.
2. **Don't fuse two separately-true facts into one claim that was never
   itself observed.** ("`nire`'s home lives under the `restic-backup`
   share" welded a *label* from one comment to a *path* confirmed
   elsewhere — neither observation actually said that together.) A gap
   between two true statements is a hole, not a bridge.
3. **Before restating or copying forward any "Status as of `<date>`"
   line, check whether the date is old enough that the underlying fact
   could have changed** — and if the fact is checkable right now (a file
   in the tree, a command), check it instead of trusting the date.
4. **When something can't be checked without access you don't have right
   now** (a NAS admin UI, a decrypt key, hardware you're not on) — don't
   fill the gap with the most-plausible guess, and don't stamp today's
   date on a claim you didn't verify today. Write the open question down,
   or ask.
5. **Precision or a date beyond what you actually checked is a liability,
   not a feature, in text that reads as settled.** The vaguer true
   statement (or the explicitly-marked-stale one) outlives the sharper
   false one.
6. **When removing or renaming something with a name other code might
   mention** (a host, a module, a secret, an option), grep for that exact
   name across `flake/modules` — not just `wiki/`, not just the files the
   change itself touches — before considering the removal finished. A
   mention that doesn't note "since removed"/"since renamed" the way this
   repo's other removed-host comments do is the tell that it was missed.

## Catching it when a claim like this turns out wrong

1. Grep the fact (or the stale claim's wording) across the whole tree —
   `grep -rn "<old claim/path/name>" wiki/ flake/` — a dated-sounding
   claim gets copied into more files than an obviously-uncertain one does,
   exactly because it reads as safe to reuse verbatim.
2. Fix it everywhere it was copied in the same change (`wiki-sync`
   skill's mechanical half), and correct the *confidence level*, not just
   the content — replace a guessed specific or a stale date with either
   the verified current fact or an explicit `UNVERIFIED`/`unconfirmed
   since <date>` marker, not just one unqualified claim for another.
3. If a comment recorded *why* the wrong claim was believed, leave that
   reasoning visible rather than deleting it — the next reader benefits
   from seeing how a plausible-sounding claim got made, per this repo's
   "a bug recorded in a comment stays in the file" convention.

## See also

- `wiki-sync` skill — the mechanical half for `wiki/`: once a fact is
  known stale, find and fix every page it reached. Scoped to `wiki/` only;
  category 3 above is the same principle applied to `flake/` code
  comments, which that skill doesn't cover.
- `AGENTS.md`'s "State" section — the existing, narrower version of
  category 2's rule, scoped to switch/boot status; this skill generalizes
  it to any dated snapshot of mutable external state.
- `restic.nix`'s header, `wiki/categories/backup.md`,
  `wiki/homelab/backup-runbook.md`, `wiki/homelab/pending-setup.md` — the
  categories 1/2 worked (mis)examples, including the `UNVERIFIED` markers
  and corrected dates added once each pattern was caught.
- `forgejo.nix`, `golink.nix`, `bash.nix` (their `/root`-wipe and
  desktop-import comments) vs. `podman.nix`/`hosts.nix`/`invariants.nix`/
  `category-collector.nix` — category 3's broken and correct examples,
  found in the same 2026-09-03 sweep.
