---
name: review
description: How to review a change in this repo — the repo-specific checks and known traps a generic reviewer doesn't know.
---

# Reviewing a change in nixos-configs

## Applies to

You're asked to review a PR, a branch, or a colleague's (or your own
earlier) commit in this repo — or you're about to say "done" about your own
change and want the same gate a reviewer would apply. Supplements, not
replaces, a generic code-review pass: it catches the failure modes this
repo's own history has already hit once, which are exactly the ones a
general nix/git reviewer won't know to look for (issue #223, 2026-09-09).

Does not fire for writing a module in the first place — the trap-specific
skills below own their tasks end to end; this file is their review-side
compression, not a duplicate.

## Run first — the mechanical checks

A diff read is never enough here; bugs serialize. Run, in this order:

1. `just modules` — catches two shapes a diff alone hides: a module renamed
   out of agreement with its category (silently collected by *nothing*), and
   two modules declaring the same `flake.modules.<class>.<name>` (they
   **merge**, they don't conflict). Also nags untracked files.
2. `git status --short` — **`git add` before `nix eval`**: a new file that
   is untracked does not exist to the flake. An eval that "passes" may have
   never seen the change.
3. `just preflight` — check + modules + lint (statix/deadnix ratchet).
4. A **forced toplevel** per host the change could touch:
   `nix eval --raw '.#nixosConfigurations.<host>.config.system.build.toplevel.drvPath'`
   (darwin:
   `.#darwinConfigurations.nire-lysithea.…`). A cheap attribute evaluating
   proves nothing — `networking.hostName` resolved happily once while four
   separate things were broken.
5. `just wiki-lint` — if the change touches `wiki/`, `AGENTS.md`, recipes,
   skills, host lists, or counts, this is the only thing reading those
   claims against the tree.
6. If a drvPath moved: `just diff <ref>` — a permuted
   `environment.systemPackages` is not a value change, and a same-looking
   hash can hide dead code. (Known gap #242: `diff` fails on cube — the
   fingerprint assumes impermanence's `/persist`; fall back to
   `nix eval --json` of the specific options on both sides.)

## Read for — the traps a diff can't show

Per changed file, the question that catches each:

- **Is it filed in the right directory?** Category membership comes from
  the directory; a module one level off is collected by nothing, no error.
  A `.nix` file *directly in* a category directory is also collected by
  nothing. (`new-flake-module` skill has the full mechanism.)
- **Do two files write the "same" file?** `home.file.<n>.text` and
  `home.sessionPath` **concatenate** across modules — a second writer
  doubles the output silently. Reading a generated dotfile back is full of
  false negatives; eval the attribute instead. (`home-manager-dotfiles`.)
- **Any `${…}` inside a `''` string?** If it's meant as shell text or a
  comment, it must be `''${…}` — unescaped, it's Nix interpolation and
  usually an eval error (or worse, a silent one).
- **Does anything put `flake.modules` inside `perSystem`?** No `<system>`
  axis there; it cannot work.
- **Does the change touch impermanence, initrd, `fileSystems`, or boot?**
  Slow down and read the `impermanence-initrd` skill before judging — the
  shell's view of mounts can be wrong while looking right
  (`/proc/1/mountinfo`, `/dev/disk/by-uuid/` instead). Check which host
  wipes `/root` in `hosts.nix` before reasoning about impact; not all do.
- **Platform gating done right?** Platform support is *derived* (off
  `meta.platforms`); a hand-written `lib.mkIf (!pkgs.stdenv.isDarwin)`
  restating it is a finding. The other half — Homebrew overlap — is never
  automatic; `just available --duplicates`. (`nirepackages-platform-support`.)
- **Was an existing `programs.*` integration missed?** Check before a
  hand-rolled dotfile/bundle survives review.

## Conventions worth flagging as findings

- **Provenance trailer** on agent-authored commits: `Co-Authored-By: <agent>`,
  agent name only, no model, no email. Conventional-Commits prefix on the
  first line only.
- **A bug recorded in a comment stays in the file** — a diff deleting a
  "why" comment needs a reason, and a stranded one should move to a
  `history` heading, not vanish.
- **Renamed away an old name?** The declaration should say what it was,
  or it's ungreppable.
- **Dated "as of" claims in docs/comments**: a date is when someone last
  checked, not proof it's still true (`fact-hygiene`). Present-tense
  claims about other files' contents are live pointers — will they survive
  the change being reviewed?
- **Wiki touched?** `wiki-sync` is part of the same change, not a follow-up.
- **Filing bugs upstream** (nixpkgs, ble.sh, …): never in this repo's name
  without Elly saying so explicitly. Even filings *here* can ping upstream
  via `owner/repo#123` autolinking — grep the draft.

## Saying the outcome

Treat an undated "verified" as *evaluates* — say which it was: in the tree,
or switched and checked live (`investigate-bug`'s step 4). "It works" from
an eval is the exact overclaim this repo keeps teaching not to make.

## See also

- The four trap skills (`new-flake-module`, `home-manager-dotfiles`,
  `impermanence-initrd`, `nirepackages-platform-support`) — the worked
  examples this checklist compresses.
- `ship` skill — the pre-PR gate this review complements; its step 0 is
  the "Run first" list above, from the author's side.
- `wiki/lessons-learned.md` — every § above earned its place the hard way.
