# Wiki

_Last modified: 2026-09-14_

The `flake/` folder is meant to be browsed by its file tree rather than
traced through by following code paths. The heavy modularization
([architecture.md](architecture.md)) exists to make documenting
functionality in-situ possible, and to keep the context any single
reader -- agent or human -- has to load down to just the chunk they're
looking at, instead of the whole tree.

A topic index over documentation that already exists scattered around this
repo — `CLAUDE.md`, `flake/doc/`, `.agents/skills/`, stray `.md` files
sitting next to the code they're about, and
`_loose-ends/bugs-pending-submission/`. Almost nothing has been moved
here: every link below points at the file that's already the source for
that fact. The exception is `claude cave/`'s
four working-notes files, moved in as real pages 2026-09-02 when that
directory was retired — the same "index over restatement, except here"
shape `wiki/homelab/` pages and `categories/shell-config/`'s deep-dives
already used; see [styleguide.md](styleguide.md)'s Directory hierarchy
section for which tiers are allowed to hold synthesized content instead of
links, and why.

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

**Every long page here has two versions.** `<page>.md` is the explanation;
`<page>-for-agents.md` is the same ground condensed to facts, for an agent
(or anyone) loading it to get one thing done rather than to read it. The
rule, and the lint check that keeps the pair in step, is
[styleguide.md](styleguide.md)'s
[Two audiences per page](styleguide.md#two-audiences-per-page).

**Don't know what you're after yet?** Start with [Overview](overview.md) —
the 2-minute mental model this index assumes. Already know what you're
trying to do? Skip straight to Common tasks below.

> **Condensed version:**
> [00-INDEX-for-agents.md](00-INDEX-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [Common tasks](#common-tasks)
- [Pages](#pages)
- [Keeping this from rotting](#keeping-this-from-rotting)

## Common tasks

A task-shaped way in, for when you already know what you're about to *do*
rather than what category it falls under. Every row points at a page above
or a skill (`.agents/skills/<name>/SKILL.md`) — nothing here is new content.

| I want to... | Start here |
|---|---|
| reach or debug a service running on cube | [homelab/reaching-services.md](homelab/reaching-services.md) |
| add, rename, or wire a flake-parts module | [architecture.md](architecture.md), skill [`new-flake-module`](../.agents/skills/new-flake-module/SKILL.md) |
| touch impermanence or initrd | [impermanence-and-secrets.md](impermanence-and-secrets.md), skill [`impermanence-initrd`](../.agents/skills/impermanence-initrd/SKILL.md) |
| add or platform-gate a package | [categories/00-INDEX.md](categories/00-INDEX.md), skill [`nirepackages-platform-support`](../.agents/skills/nirepackages-platform-support/SKILL.md) |
| land a change on `experimental` | [conventions.md](conventions.md), skill [`ship`](../.agents/skills/ship/SKILL.md) |
| check whether a bug is already a known thread | [open-threads.md](open-threads.md), skill [`investigate-bug`](../.agents/skills/investigate-bug/SKILL.md) |
| add a self-hosted service to a host | [homelab/00-INDEX.md](homelab/00-INDEX.md), skill [`new-homelab-service`](../.agents/skills/new-homelab-service/SKILL.md) |
| give a service its own Tailscale Services (`svc:`) hostname | [categories/reverse-proxy.md](categories/reverse-proxy.md), skill [`new-tailscale-service`](../.agents/skills/new-tailscale-service/SKILL.md) |
| add a new host, or format its disk for impermanence | [disk-formatting.md](disk-formatting.md), skill [`new-host-config`](../.agents/skills/new-host-config/SKILL.md) |
| check what key/credential expiry is coming due | [maintenance-schedule.md](maintenance-schedule.md), skill [`maintenance-schedule`](../.agents/skills/maintenance-schedule/SKILL.md) |
| run the fleet's periodic upkeep — lock PR, deploys, store hygiene | [maintenance.md](maintenance.md) |
| work out which name or IP answers for what (forward, reverse, `.local`, `svc:`) | [name-resolution.md](name-resolution.md) |

## Pages

### Cross-cutting topics

- [Overview](overview.md) — the 2-minute mental model: what this repo is,
  the shape of it, what's distinctive here, and where to go next. Start
  here if you're new; everything else on this page assumes you've read it
  or don't need to.
- [Hosts & current state](hosts.md) — the four hosts (three NixOS + one
  darwin), what's actually been switched/booted vs. only evaluated, and
  where that status is tracked.
- [New host disk formatting](disk-formatting.md) — the LUKS + btrfs +
  impermanence disk layout runbook: what to decide before touching a real
  disk, what depends on disko actually having run, and how to confirm the
  `/root` rollback is really working rather than just booting.
- [flake-parts](flake-parts.md) — why this repo runs flake-parts at all:
  its `flake.modules.<class>.<name>` option lets a single file declare a
  NixOS module and a Home Manager module for the same feature side by
  side, instead of splitting one feature across two files tied together
  only by a shared filename. Ahead of
  [Architecture & module system](architecture.md), which is the
  `dirsAsCategory` mechanism, Home Manager integration, and package
  modules built on top of it.
- [Impermanence, initrd & secrets](impermanence-and-secrets.md) — the
  `/root`-wipe-on-boot mechanism, which hosts opt in, sops-nix.
- [Traps & skills](traps-and-skills.md) — the mistakes that have actually
  happened here, and the skills that hold the long version of each.
- [History & lessons learned](history.md) — the den → flake-parts port, the
  first hardware boots, and what became of the sibling branch. The full log
  itself, [lessons-learned.md](lessons-learned.md) — numbered §1–48 with a
  one-line summary each, long entries broken out into `lessons-learned/`
  articles (2026-09-09), "written by Claude Code, for Claude Code" — moved
  in from `claude cave/` 2026-09-02; this page stays the index, that page
  stays the log, the same split as `categories/shell-config/00-INDEX.md` and
  its deep-dives.
- [flake-parts port notes](flake-parts-port-notes.md) — salvaged 2026-09-08
  from the deleted `flake-parts` branch: the port's decisions-not-defaults,
  its dead ends with the symptom that identified each, and a flake-parts
  machinery reference backed by the pinned upstream source. Content, not an
  index, because the branch it linked to is gone.
- [Open threads](open-threads.md) — pending upstream bug reports, todos,
  half-formed ideas, and things-to-look-into notes left in various corners.
- [Maintenance schedule](maintenance-schedule.md) — the fleet's keys,
  credentials, and certificates that have an actual expiry, rotation
  cadence, or silent-breakage property; tended by skill
  [`maintenance-schedule`](../.agents/skills/maintenance-schedule/SKILL.md).
- [Fleet maintenance](maintenance.md) — the recurring upkeep beyond
  credentials: the weekly flake.lock PR, deploying and the verification
  habit around it, and store hygiene (what runs itself, what doesn't).
- [Name resolution & reverse DNS](name-resolution.md) — which name
  source answers for what (MagicDNS devices vs `svc:` VIPs, `.local`,
  golink's device), what PTR returns for tailnet IPs, and where those
  names render — including why Caddy's logs never show a peer address.

### Category reference (configuration)

- [Category reference](categories/00-INDEX.md) — one article per real
  category (`config-system/system`, `config-system/impermanence`, `config-system/homelab/virtualization`, …):
  what's in it, which hosts import it, and the traps specific to that one.
  [shell-config](categories/shell-config/00-INDEX.md) is the one category
  that's grown its own subdirectory, with deep-dives on
  [blesh](categories/shell-config/blesh.md) (the hand-wired bash line
  editor config, and an open upstream bug found while diagnosing a
  spurious `read` error on Tab-completion) and
  [carapace](categories/shell-config/carapace.md) (the completion engine
  blesh layers a menu on top of, and how it avoids clobbering — and being
  clobbered by — `cod`'s daemon-based completions).

### Homelab (usage)

- [Homelab services](homelab/00-INDEX.md) — how to *use* what the fleet
  actually runs, as opposed to how it's configured:
  [reaching cube's services](homelab/reaching-services.md) (the URL map
  since everything moved behind one HTTPS hostname on 2026-08-24, and what
  to check when something doesn't answer),
  [using the forge](homelab/forgejo.md),
  [using Grafana](homelab/grafana.md), and
  [creating go/ links](homelab/creating-golinks.md), plus
  [pending setup](homelab/pending-setup.md) — what's running but not
  finished, now down to go/ links, homepage's calendar feeds, and the
  mirror-or-origin question. A different tier from the category pages, and the one place a
  page may hold real content rather than links — because its source is
  often the running service's own help page, not a file in this repo.

### Experiments (open questions)

- [Experiments](experiments/) — one page per problem that is **instrumented
  but not yet diagnosed**, kept separate from the category pages so that
  "we're still measuring this" never gets read as settled config:
  [durandal's auto-suspend hang](experiments/durandal-auto-suspend-hang.md)
  (sleeps into S3 and won't wake without a PSU power cut; the kernel reports
  those as `success`, so an on-disk probe and `amdgpu.runpm=0` are under test). When a question closes, the
  outcome moves to [lessons-learned.md](lessons-learned.md) or the relevant
  category page and the experiment page goes.

### Conventions & meta

- [Conventions & workflow](conventions.md) — the *repo's* style guide: Nix
  formatting, `just` commands, the `ship` flow, assorted fix snippets. Links
  out to [module-style-guide.md](module-style-guide.md) for the full
  `flake/modules/` conventions doc (aligned `=` columns, the module header,
  why `nix fmt` isn't wired up) — moved in from `claude cave/` 2026-09-02.
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
