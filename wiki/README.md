# Wiki

A topic index over documentation that already exists scattered around this
repo — `CLAUDE.md`, `claude cave/`, `flake/doc/`, `.claude/skills/`, stray
`.md` files sitting next to the code they're about, and `bugs pending
submission/`. Nothing has been moved here: every link below points at the
file that's already the source for that fact.

**Why a link layer and not a rewrite:** this repo has already been bitten,
repeatedly, by the same fact living in two places and drifting — `CLAUDE.md`'s
own host-count and Safety sections carry visible scar tissue from exactly
that ("this paragraph said N until..."). Copying content into wiki pages
would just add a third and fourth place for the same drift. So these pages
are indexes and short orientation notes, not restatements — when in doubt,
follow the link and read the file it points to, not this page's paraphrase
of it.

**Not a replacement for `CLAUDE.md`.** `CLAUDE.md` is still the agent-facing
entry point and the one thing worth reading cold before touching this repo.
This wiki exists for the "where do I even look" problem once you already
know roughly what you're after — a human skimming for the right doc, or an
agent trying to find the one file that actually answers a question instead
of re-deriving it.

## Pages

- [Hosts & current state](hosts.md) — the five hosts (four NixOS + one
  darwin) plus the live-USB installer, what's actually been switched/booted
  vs. only evaluated, and where that status is tracked.
- [Architecture & module system](architecture.md) — flake-parts, the
  `dirsAsCategory` mechanism, Home Manager integration, package modules.
- [Category reference](categories/README.md) — one article per real
  category (`nire/system`, `nire/impermanence`, `nire/virtualization`, …):
  what's in it, which hosts import it, and the traps specific to that one.
- [Impermanence, initrd & secrets](impermanence-and-secrets.md) — the
  `/root`-wipe-on-boot mechanism, which hosts opt in, sops-nix.
- [Traps & skills](traps-and-skills.md) — the mistakes that have actually
  happened here, and the skills that hold the long version of each.
- [History & lessons learned](history.md) — the den → flake-parts port, the
  first hardware boots, and the sibling branch's own notes.
- [Conventions & workflow](conventions.md) — style guide, `just` commands,
  the `ship` flow, assorted fix snippets.
- [Open threads](open-threads.md) — pending upstream bug reports, todos,
  half-formed ideas, and things-to-look-into notes left in various corners.

## Keeping this from rotting

If a linked file moves or is renamed, this wiki's links break silently —
there's no CI check tying the two together. Update the link when you notice
it's stale; don't let a wiki page assert something the file it points to no
longer says. If a page here starts accumulating actual facts instead of
links (a paragraph explaining *why*, not just *where*), that's a sign the
fact belongs in the linked file's own header instead, per this repo's
existing convention of keeping explanations next to the code they explain.
