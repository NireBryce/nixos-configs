# Wiki

_Last modified: 2026-10-31_

This is the wiki's topic index. The `flake/` folder is meant to be browsed by
its file tree, with documentation next to the code; the heavy modularization
([config-structure/architecture.md](config-structure/architecture.md)) keeps the context a reader loads down to
the chunk they're looking at. Almost nothing is restated here: each link
points at the file that is already the source for that fact (`CLAUDE.md`,
`flake/doc/`, `.agents/skills/`, `.md` files next to the code they cover,
`_loose-ends/bugs-pending-submission/`). When in doubt, follow the link
rather than trusting this page's paraphrase.

**Why links and not a rewrite.** The same fact living in two places has
repeatedly drifted here; `CLAUDE.md`'s host-count and Safety sections still
carry the scar tissue ("this paragraph said N until..."). Copying content into
wiki pages would add a third and fourth place. The exceptions are pages with
no other source to link to: the working-notes files moved in from
`claude cave/` (retired 2026-09-02), the `wiki/homelab/` pages, and
`categories/shell-config/`'s deep-dives. [meta/styleguide.md](meta/styleguide.md)'s
Directory hierarchy section says which tiers may hold synthesized content.

**This wiki doesn't replace `CLAUDE.md`**, the agent-facing entry point and
the one thing worth reading cold before touching this repo. The wiki answers
"where do I even look" once you know roughly what you're after.

**Long pages come in one of two shapes.** Where the explanation is long
narrative, there are two versions: `<page>.md` is the explanation,
`<page>-for-agents.md` the same ground condensed to facts, for an agent (or
anyone) loading it to get one thing done rather than to read it. Where a
condensed copy would only restate the page, there is one page that opens
with a `## Quick facts` section instead. The rule, and the lint check that
keeps a pair in step, is
[meta/styleguide.md](meta/styleguide.md)'s
[Two audiences per page](meta/styleguide.md#two-audiences-per-page).

**Many agent skills and safeguards only trigger under bash.** The guard
hooks match the harness's `Bash` tool (the secrets read guard matches
`Read`/`Grep`/`Glob`, the edit hooks `Edit`/`Write`), and the skills and
recipes are written as bash commands. Another shell, or a tool other than
`Bash`, bypasses the git, `just`, nix and secrets command checks. An agent
using one should warn the user. See
[Checks, guards and hooks](../book/src/agent-checks-and-guards.md).

**Don't know what you're after yet?** Start with [Overview](overview.md).
If you do, skip to Common tasks below.

> **Condensed version:**
> [00-INDEX-for-agents.md](00-INDEX-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [Layout](#layout)
- [Common tasks](#common-tasks)
- [Pages](#pages)
- [Keeping this from rotting](#keeping-this-from-rotting)

## Layout

The wiki is sorted by what a reader is doing, one folder per cluster; the
root holds only entry points.

- [`config-structure/`](config-structure/) — how the flake is built:
  [architecture](config-structure/architecture.md),
  [flake-parts](config-structure/flake-parts.md),
  [module files](config-structure/module-files.md),
  [where modules go](config-structure/where-modules-go.md), the style guides,
  [impermanence and secrets](config-structure/impermanence-and-secrets.md),
  and [`categories/`](config-structure/categories/00-INDEX.md), one page per category.
- [`fleet/`](fleet/) — the machines: [hosts](fleet/hosts.md),
  [disk formatting](fleet/disk-formatting.md),
  [name resolution](fleet/name-resolution.md), [durandal gaming](fleet/durandal-gaming.md),
  [FHS environments](fleet/fhs-environments.md).
- [`upkeep-and-admin/`](upkeep-and-admin/) — recurring chores:
  [maintenance](upkeep-and-admin/maintenance.md),
  [expiry schedule](upkeep-and-admin/maintenance-schedule.md),
  [flake.lock bump](upkeep-and-admin/flake-lock-weekly-bump.md),
  [temporary patches](upkeep-and-admin/temporary-patches-and-hacks.md).
- [`llm-aided-dev/`](llm-aided-dev/) — working with coding agents:
  [cloud sessions](llm-aided-dev/cloud-sessions.md) (plan and runbook).
- [`meta/`](meta/) — the wiki's own rules and the repo's memory:
  [style guide](meta/styleguide.md), [traps and skills](meta/traps-and-skills.md),
  [history](meta/history.md), [open threads](meta/open-threads.md), and `scripts/`.
- [`homelab/`](homelab/00-INDEX.md) (using services) and
  [`experiments/`](experiments/) (undiagnosed problems) are unchanged.

## Common tasks

A task-shaped way in, for when you already know what you're about to *do*
rather than what category it falls under. Every row points at a page above
or a skill (`.agents/skills/<name>/SKILL.md`) — nothing here is new content.

| I want to... | Start here |
|---|---|
| reach or debug a service running on cube | [homelab/reaching-services.md](homelab/reaching-services.md) |
| stream cube's desktop, clear a lock-screen lockout, open Sunshine's web UI | [homelab/common-commands.md](homelab/common-commands.md) |
| restart, add to, or debug cube's Claude Remote Control sessions | [homelab/claude-rc.md](homelab/claude-rc.md) |
| add, rename, or wire a module file | [config-structure/architecture.md](config-structure/architecture.md), skill [`new-flake-module`](../.agents/skills/new-flake-module/SKILL.md) |
| decide where a new module goes (shared, host, or user) | [config-structure/where-modules-go.md](config-structure/where-modules-go.md) |
| touch impermanence or initrd | [config-structure/impermanence-and-secrets.md](config-structure/impermanence-and-secrets.md), skill [`impermanence-initrd`](../.agents/skills/impermanence-initrd/SKILL.md) |
| add or platform-gate a package | [config-structure/categories/00-INDEX.md](config-structure/categories/00-INDEX.md), skill [`package-platform-support`](../.agents/skills/package-platform-support/SKILL.md) |
| land a change on `experimental` | [config-structure/conventions.md](config-structure/conventions.md), skill [`ship`](../.agents/skills/ship/SKILL.md) |
| check whether a bug is already a known thread | [meta/open-threads.md](meta/open-threads.md), skill [`investigate-bug`](../.agents/skills/investigate-bug/SKILL.md) |
| add a self-hosted service to a host | [homelab/00-INDEX.md](homelab/00-INDEX.md), skill [`new-homelab-service`](../.agents/skills/new-homelab-service/SKILL.md) |
| give a service its own Tailscale Services (`svc:`) hostname | [config-structure/categories/reverse-proxy.md](config-structure/categories/reverse-proxy.md), skill [`new-tailscale-service`](../.agents/skills/new-tailscale-service/SKILL.md) |
| add a new host, or format its disk for impermanence | [fleet/disk-formatting.md](fleet/disk-formatting.md), skill [`new-host-config`](../.agents/skills/new-host-config/SKILL.md) |
| check what key/credential expiry is coming due | [upkeep-and-admin/maintenance-schedule.md](upkeep-and-admin/maintenance-schedule.md), skill [`maintenance-schedule`](../.agents/skills/maintenance-schedule/SKILL.md) |
| run the fleet's periodic upkeep — lock PR, deploys, store hygiene | [upkeep-and-admin/maintenance.md](upkeep-and-admin/maintenance.md), [upkeep-and-admin/flake-lock-weekly-bump.md](upkeep-and-admin/flake-lock-weekly-bump.md) |
| work out which name or IP answers for what (forward, reverse, `.local`, `svc:`) | [fleet/name-resolution.md](fleet/name-resolution.md) |

## Pages

### Cross-cutting topics

- [Overview](overview.md) — the 2-minute mental model: what this repo is,
  the shape of it, what's distinctive here, and where to go next. Start
  here if you're new; everything else on this page assumes you've read it
  or don't need to.
- [Hosts & current state](fleet/hosts.md) — the hosts (NixOS and
  darwin), what's been switched/booted vs. only evaluated, and
  where that status is tracked.
- [Durandal gaming](fleet/durandal-gaming.md) — what durandal runs games with:
  shared Steam, its own Heroic and GameMode (added for Alan Wake 2), the
  GameMode polkit group, and what's worth adding next.
- [FHS environments and /etc evidence](fleet/fhs-environments.md) — the bwrap
  namespaces on this fleet, what an agent shell inherits from them, and the
  merge-into-mutable-files custody rule their config files follow.
- [New host disk formatting](fleet/disk-formatting.md) — the LUKS + btrfs +
  impermanence disk layout runbook: what to decide before touching a real
  disk, what depends on disko having run, and how to confirm the
  `/root` rollback is really working rather than just booting.
- [flake-parts](config-structure/flake-parts.md) — why this repo runs flake-parts at all:
  its `flake.modules.<class>.<name>` option lets a single file declare a
  NixOS module and a Home Manager module for the same feature side by
  side, instead of splitting one feature across two files tied together
  only by a shared filename. Ahead of
  [Architecture & module system](config-structure/architecture.md), which is the
  category mechanism, Home Manager integration, and package
  modules built on top of it. [Module files](config-structure/module-files.md) is why every
  module looks the way it does -- names from filenames, categories from folders.
- [Impermanence, initrd & secrets](config-structure/impermanence-and-secrets.md) — the
  `/root`-wipe-on-boot mechanism, which hosts opt in, sops-nix.
- [Traps & skills](meta/traps-and-skills.md) — the mistakes that have
  happened here, and the skills that hold the long version of each.
- [History & lessons learned](meta/history.md) — the den → flake-parts port, the
  first hardware boots, and what became of the sibling branch. The full log
  itself, [agent-lessons-learned.md](agent-lessons-learned.md) — every numbered lesson
  as one line, grouped by the moment it applies (since 2026-09-29), each
  linking its full account under `agent-lessons-learned/` (and, by file or
  area, `just agent lessons <path>`), "written by Claude Code, for Claude
  Code" — moved
  in from `claude cave/` 2026-09-02; this page stays the index, that page
  stays the log, the same split as `categories/shell-config/00-INDEX.md` and
  its deep-dives.
- [flake-parts port notes](config-structure/flake-parts-port-notes.md) — salvaged 2026-09-08
  from the deleted `flake-parts` branch: the port's decisions-not-defaults,
  its dead ends with the symptom that identified each, and a flake-parts
  machinery reference backed by the pinned upstream source. Content, not an
  index, because the branch it linked to is gone.
- [Open threads](meta/open-threads.md) — where the repo's loose ends are
  tracked (GitHub issues, by label), and the rule for upstream write-ups.
- [Temporary patches and hacks](upkeep-and-admin/temporary-patches-and-hacks.md) — every
  workaround in the config that exists because of a third-party bug, and
  the condition for removing each.
- [Maintenance schedule](upkeep-and-admin/maintenance-schedule.md) — the fleet's keys,
  credentials, and certificates that have an actual expiry, rotation
  cadence, or silent-breakage property; tended by skill
  [`maintenance-schedule`](../.agents/skills/maintenance-schedule/SKILL.md).
- [flake.lock updates](upkeep-and-admin/flake-lock-weekly-bump.md) — the weekly bump and the PR that
  lands it; where the GitHub credential for it lives.
- [Fleet maintenance](upkeep-and-admin/maintenance.md) — the recurring upkeep beyond
  credentials: the weekly flake.lock PR, deploying and the verification
  habit around it, and store hygiene (what runs itself, what doesn't).
- [Name resolution & reverse DNS](fleet/name-resolution.md) — which name
  source answers for what (MagicDNS devices vs `svc:` VIPs, `.local`,
  golink's device), what PTR returns for tailnet IPs, and where those
  names render — including why Caddy's logs never show a peer address.

### Category reference (configuration)

- [Category reference](config-structure/categories/00-INDEX.md) — one article per real
  category (`general-config/system`, `general-config/impermanence`, `homelab-config/homelab/virtualization`, …):
  what's in it, which hosts import it, and the traps specific to that one.
  [shell-config](config-structure/categories/shell-config/00-INDEX.md) is the one category
  that's grown its own subdirectory, with deep-dives on
  [blesh](config-structure/categories/shell-config/blesh.md) (the hand-wired bash line
  editor config, and an open upstream bug found while diagnosing a
  spurious `read` error on Tab-completion) and
  [carapace](config-structure/categories/shell-config/carapace.md) (the completion engine
  blesh layers a menu on top of, and how it avoids clobbering — and being
  clobbered by — `cod`'s daemon-based completions), and
  [cod-desc](config-structure/categories/shell-config/cod-desc.md) (menu descriptions for
  those `cod` completions, which store none anywhere).

### Homelab (usage)

- [Homelab services](homelab/00-INDEX.md) — how to *use* what the fleet
  runs, as opposed to how it's configured:
  [reaching cube's services](homelab/reaching-services.md) (the URL map
  since everything moved behind one HTTPS hostname on 2026-08-24, and what
  to check when something doesn't answer),
  [using the forge](homelab/forgejo.md),
  [practicing a workplace coding environment with it](homelab/practice-environment.md),
  [using Grafana](homelab/grafana.md), and
  [creating go/ links](homelab/creating-golinks.md), plus
  [pending setup](homelab/pending-setup.md) — what's running but not
  finished, tracked as `pending-setup`-labelled issues. A different tier from the category pages, and the one place a
  page may hold real content rather than links — because its source is
  often the running service's own help page, not a file in this repo.

### Experiments (open questions)

- [Experiments](experiments/) — one page per problem that is **instrumented
  but not yet diagnosed**, kept separate from the category pages so that
  "we're still measuring this" never gets read as settled config:
  [durandal's auto-suspend hang](experiments/durandal-auto-suspend-hang.md)
  (sleeps into S3 and won't wake without a PSU power cut; the kernel reports
  those as `success`; `amdgpu.runpm=0` was tried 2026-09-14 and failed, and
  nothing is under test now), and
  [tenacity's SD card reader](experiments/tenacity-sd-reader-enumeration.md)
  (fails to enumerate on about half of boots since 6.18.57 and slows the
  lock-screen YubiKey prompt; tabled until a kernel bump). The directory
  also holds [what is instrumented on durandal right now](experiments/durandal-suspend-instrumentation-state.md)
  and [a historical 2026-09-16 probe transcript](experiments/durandal-superio-probe-runbook-2026-09-16.md).
  When a question closes, the
  outcome moves to [agent-lessons-learned.md](agent-lessons-learned.md) or the relevant
  category page and the experiment page goes.

### Conventions & meta

- [Conventions & workflow](config-structure/conventions.md) — the *repo's* style guide: Nix
  formatting, `just` commands, the `ship` flow, assorted fix snippets. Links
  out to [config-structure/module-style-guide.md](config-structure/module-style-guide.md) for the full
  `flake/modules/` conventions doc (aligned `=` columns, the module header,
  why `nix fmt` isn't wired up) — moved in from `claude cave/` 2026-09-02.
- [Wiki style guide](meta/styleguide.md) — this wiki's *own* house style: the
  directory hierarchy above in full (when a category page earns its own
  subdirectory, like `shell-config` did), naming, linking, and how pages
  here are meant to stay index-shaped instead of drifting into a second
  copy of the facts they point at.

## Keeping this from rotting

If a linked file moves or is renamed, this wiki's links break silently —
there's no CI check tying the two together. [meta/styleguide.md](meta/styleguide.md)
has the full rule; the short version is the same one `CLAUDE.md` holds
itself to: whichever change makes a page stale corrects it in the same
change, not as a follow-up.
