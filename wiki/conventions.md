# Conventions & workflow

## Commands

`just` recipes (root `.justfile`, work from anywhere) — full list in
[`../CLAUDE.md`](../CLAUDE.md)'s Commands section. The ones worth knowing
exist: `just check`, `just modules` (the only static check that means
anything on darwin), `just wiki-lint` (checks this wiki's own "Imported by"
claims and category member counts against the real module tree — added
2026-08-27, `wiki/scripts/check_wiki.py`; not yet part of `preflight`),
`just available <pkg>` / `--duplicates`, `just build`/`boot`/`switch`
(dispatch per host class via `scripts/rebuild.sh`), and the
hardware-only, read-only `just baseline` / `hm-collisions` /
`diff-deployed` / `root-drift`.

`host` derives from `hostname`; override with `just host=<name> <recipe>`
(the override goes *before* the recipe name — `just build host=…` is parsed
as a second recipe, not a flag, and errors).

## Landing changes on `experimental`

Skill `ship` (`.claude/skills/ship/SKILL.md`) — branch → PR → confirm →
merge → confirm → delete-branch. Two confirmations, not one. Only for work
headed to `experimental`; pushing a topic branch is just a push. "Push" in
conversation means this flow, not `git push origin main` directly. Redirected
from `main` to `experimental` 2026-08-25 — GitHub's default branch and its
only branch ruleset are still `main`, so the flow states `--base
experimental` explicitly; naming a branch outright (`main` included) means
push directly there instead.

## Style

- **[`../claude cave/claude-style-guide.md`](<../claude cave/claude-style-guide.md>)**
  — the full conventions doc for `flake/modules/`.
- **Namespacing** — `nire` unless something needs a more specific tag;
  `nireHost`, `nireUser`, `nirePackages` otherwise.
- **Renames** — when a rename makes the old name ungreppable, say what it
  was on the declaration (`boot-durandal.nix`, `enable-home-manager.nix` are
  the worked examples).
- **Stranded comments** — a bug recorded in a comment stays in the file even
  after the fix lands; nobody reads `git log`, the comment is what the next
  editor sees. If a later change stands a comment (the code it described is
  gone, the name it explained has changed), move it to a `history` heading
  at the bottom rather than deleting it, and expand it to stand alone.
- **Don't bury Python inside bash** — a little Python in an otherwise-shell
  script goes in `flake/scripts/util/` as a real `.py` file; mostly-Python
  work is written as Python outright (`modules.py` is the precedent). Grew
  out of a package-availability checker that shipped both bugs this
  shape invites (env vars read where argv was expected, a mangled line
  nothing highlighted).

## Fix snippets & one-offs

**[`../flake/doc/notes-and-fixes.md`](<../flake/doc/notes-and-fixes.md>)** —
a grab-bag, not organized by topic:

- `SteamTinkerLaunch` workarounds (external gist link).
- `programs.command-not-found.enable = lib.mkForce false;` — thought to be
  redundant now that `nix-index-database` is in the flake.
- A pure-vs-impure `nixos-rebuild dry-build -vvv` + `diff -y` trick for
  finding where a build depends on impure state.
- Several `boot.kernelPackages` / `musnix.kernel.packages` override
  patterns, pinning to specific kernel versions/sources.
- `environment.pathsToLink` note (what controls what lands in
  `/run/current-system/sw`).
- Stale command reminders from before `just` existed (`nh os switch`,
  `nh home switch` by hand) — corrected inline in the file: there's no
  separate `nh home switch` step now, HM applies as part of the system, use
  `just switch`.

See also [traps-and-skills.md](traps-and-skills.md) for the two traps
general enough to live inline in `CLAUDE.md` rather than in a skill.
