---
name: review
description: How to review a change in this repo — the repo-specific checks and known traps a generic reviewer doesn't know.
---

# Reviewing a change in nixos-configs

## Applies to

Asked to review a PR, branch, or commit (yours or another's) — or about to
say "done" on your own change and want the reviewer's gate. Supplements a
generic code-review pass with failure modes this repo's history already hit
(issue #223, 2026-09-09). Not for writing a module — the trap skills below
own that; this file is their review-side compression.

## Run first — the mechanical checks

A diff read is never enough (bugs serialize). In order:

1. `just modules` — catches a module renamed out of agreement with its
   category (collected by *nothing*), and two modules declaring the same
   `flake.modules.<class>.<name>` (they **merge**). Nags untracked files.
2. `git status --short` — **`git add` before `nix eval`**: an untracked new
   file doesn't exist to the flake; a passing eval may never have seen it.
3. `just preflight` — wiki-lint + check + modules + lint (statix/deadnix
   ratchet) + script fixture tests; what CI runs.
4. **Forced toplevel** per host the change could touch:
   `nix eval --raw '.#nixosConfigurations.<host>.config.system.build.toplevel.drvPath'`
   (darwin: `.#darwinConfigurations.nire-lysithea.…`). A cheap attribute
   proves nothing (`networking.hostName` resolved while four things were broken).
5. `just wiki-lint` — if the change touches `wiki/`, `AGENTS.md`, recipes,
   skills, host lists, or counts; the only reader of those claims.
6. drvPath moved: `just diff <ref>` — permuted `environment.systemPackages`
   is not a value change; a same-looking hash can hide dead code. (Known gap
   #242: `diff` fails on cube — fingerprint assumes impermanence's
   `/persist`; fall back to `nix eval --json` of the specific options on both
   sides.)

## Read for — traps a diff can't show

- **Filed in the right directory?** Category = directory; a module outside
  every category tree is collected by nothing, no error (`new-flake-module`).
- **Two files writing the "same" file?** `home.file.<n>.text` and
  `home.sessionPath` **concatenate** across modules — silent doubling.
  Reading a generated dotfile back gives false negatives; eval the
  attribute (`home-manager-dotfiles`).
- **`${…}` inside a `''` string?** Meant as shell text/comment → must be
  `''${…}`; else Nix interpolation, usually an eval error (or silent).
- **`flake.modules` inside `perSystem`?** No `<system>` axis; can't work.
- **Touches impermanence, initrd, `fileSystems`, boot?** Read
  `impermanence-initrd` first (shell mount views mislead; use
  `/proc/1/mountinfo`, `/dev/disk/by-uuid/`). Check `hosts.nix` for which
  host wipes `/root`; not all do.
- **Platform gating?** Support is *derived* off `meta.platforms`; a
  hand-written `lib.mkIf (!pkgs.stdenv.isDarwin)` is a finding. Homebrew
  overlap is never automatic: `just available --duplicates`
  (`package-platform-support`).
- **Existing `programs.*` integration missed?** Flag hand-rolled dotfiles.
- **Anything that can print a secret?** Bare `sops -d`, `journalctl`/`ps`
  near a unit with a secret on its command line, a credential outside
  `secrets.yaml` (`secrets-hygiene`; flagged hit → `triage-flagged-secrets`
  before rotation talk).

## Conventions worth flagging

- **Trailer** on agent commits: `Co-Authored-By: <agent>`, name only, no
  model/email. Conventional-Commits prefix on the first line only.
- **A bug recorded in a comment stays in the file** — deleting a "why"
  comment needs a reason; a stranded one moves to a `history` heading.
- **Renamed-away name**: the declaration should say what it was.
- **Dated "as of" claims**: a date is when someone last checked, not proof
  (`fact-hygiene`). Present-tense claims about other files are live pointers
  — will they survive this change?
- **Wiki touched?** `wiki-sync` belongs in the same change.
- **Upstream filings** (nixpkgs, ble.sh, …): never without the user saying
  so explicitly; even filings *here* can ping upstream via `owner/repo#123`
  autolinking — grep the draft.

## Saying the outcome

An undated "verified" means *evaluates*. Say which: in the tree, or
switched and checked live (`investigate-bug` step 4). "It works" from an
eval is the overclaim this repo keeps teaching against.

## See also

- Trap skills: `new-flake-module`, `home-manager-dotfiles`,
  `impermanence-initrd`, `package-platform-support`, `secrets-hygiene`.
- `ship` — pre-PR gate; its step 0 is "Run first" from the author's side.
- `wiki/lessons-learned.md` — every § earned the hard way.
