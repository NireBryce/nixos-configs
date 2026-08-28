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

- [Hosts & current state](hosts.md) — the four hosts (three NixOS + one
  darwin), what's actually been switched/booted vs. only evaluated, and
  where that status is tracked.
- [Architecture & module system](architecture.md) — flake-parts, the
  `dirsAsCategory` mechanism, Home Manager integration, package modules.
- [Category reference](categories/README.md) — one article per real
  category (`nire/system`, `nire/impermanence`, `nire/homelab/virtualization`, …):
  what's in it, which hosts import it, and the traps specific to that one.
  [shell-config](categories/shell-config/README.md) is the one category
  that's grown its own subdirectory, with deep-dives on
  [blesh](categories/shell-config/blesh.md) (the hand-wired bash line
  editor config, and an open upstream bug found while diagnosing a
  spurious `read` error on Tab-completion) and
  [carapace](categories/shell-config/carapace.md) (the completion engine
  blesh layers a menu on top of, and how it avoids clobbering — and being
  clobbered by — `cod`'s daemon-based completions).
- [Homelab services](homelab/README.md) — how to *use* what the fleet
  actually runs, as opposed to how it's configured:
  [reaching cube's services](homelab/reaching-services.md) (the URL map
  since everything moved behind one HTTPS hostname on 2026-08-24, and what
  to check when something doesn't answer),
  [using the forge](homelab/forgejo.md), and
  [creating go/ links](homelab/golinks.md), plus
  [pending setup](homelab/pending-setup.md) — the services that are running
  but not finished (no Forgejo users, no go/ links, no backups). Grafana is
  listed but not written up. A different tier from the category pages, and the one place a
  page may hold real content rather than links — because its source is
  often the running service's own help page, not a file in this repo.
- [Impermanence, initrd & secrets](impermanence-and-secrets.md) — the
  `/root`-wipe-on-boot mechanism, which hosts opt in, sops-nix.
- [Traps & skills](traps-and-skills.md) — the mistakes that have actually
  happened here, and the skills that hold the long version of each.
- [History & lessons learned](history.md) — the den → flake-parts port, the
  first hardware boots, and the sibling branch's own notes.
- [Conventions & workflow](conventions.md) — the *repo's* style guide: Nix
  formatting, `just` commands, the `ship` flow, assorted fix snippets.
- [Open threads](open-threads.md) — pending upstream bug reports, todos,
  half-formed ideas, and things-to-look-into notes left in various corners.
- [Wiki style guide](styleguide.md) — this wiki's *own* house style: the
  directory hierarchy above in full (when a category page earns its own
  subdirectory, like `shell-config` did), naming, linking, and how pages
  here are meant to stay index-shaped instead of drifting into a second
  copy of the facts they point at.

## Keeping this from rotting

If a linked file moves or is renamed, this wiki's links break silently —
there's no CI check tying the two together. [styleguide.md](styleguide.md)
has the full rule; the short version is the same one `CLAUDE.md` holds
itself to: whichever change makes a page stale corrects it in the same
change, not as a follow-up.
