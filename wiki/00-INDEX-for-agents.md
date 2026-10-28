# Wiki index, for agents

_Last modified: 2026-10-28_

Condensed from [00-INDEX.md](00-INDEX.md). Routing only.

`flake/` is browsed by file tree ([config-structure/architecture.md](config-structure/architecture.md)). `CLAUDE.md`
is the cold-start read; this page says which file holds the answer. Pages with a
`-for-agents` sibling are listed by the sibling; load the human page only for the *why*.
A page without one opens with `## Quick facts` — linked there.

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
  [name resolution](fleet/name-resolution.md), [durandal gaming](fleet/durandal-gaming.md).
- [`upkeep-and-admin/`](upkeep-and-admin/) — recurring chores:
  [maintenance](upkeep-and-admin/maintenance.md),
  [expiry schedule](upkeep-and-admin/maintenance-schedule.md),
  [flake.lock bump](upkeep-and-admin/flake-lock-weekly-bump.md),
  [temporary patches](upkeep-and-admin/temporary-patches-and-hacks.md).
- [`meta/`](meta/) — the wiki's own rules and the repo's memory:
  [style guide](meta/styleguide.md), [traps and skills](meta/traps-and-skills.md),
  [history](meta/history.md), [open threads](meta/open-threads.md), and `scripts/`.
- [`homelab/`](homelab/00-INDEX.md) (using services) and
  [`experiments/`](experiments/) (undiagnosed problems) are unchanged.

## By task

| Task | Read |
|---|---|
| add, rename, or wire a module file | [config-structure/architecture.md](config-structure/architecture.md#quick-facts), skill `new-flake-module` |
| place a new module: shared / host / user | [config-structure/where-modules-go.md](config-structure/where-modules-go.md) |
| touch impermanence or initrd | [config-structure/impermanence-and-secrets.md](config-structure/impermanence-and-secrets.md), skill `impermanence-initrd` |
| add or platform-gate a package | [config-structure/categories/00-INDEX.md](config-structure/categories/00-INDEX.md), skill `package-platform-support` |
| add a package to a user's environment | skill `new-package` |
| land a change on `experimental` | [config-structure/conventions.md](config-structure/conventions.md), skill `ship` |
| work without clobbering another session | skill `use-a-worktree` |
| script a command pattern agents keep re-typing | skill `agent-scripts` |
| check whether a bug is already tracked | [meta/open-threads-for-agents.md](meta/open-threads-for-agents.md), skill `investigate-bug` |
| after a lock bump: can a workaround go? | [temporary-patches-and-hacks.md § Quick facts](upkeep-and-admin/temporary-patches-and-hacks.md#quick-facts) |
| add a self-hosted service | [homelab/00-INDEX.md](homelab/00-INDEX.md), skill `new-homelab-service` |
| give a service its own `svc:` hostname | [config-structure/categories/reverse-proxy-for-agents.md](config-structure/categories/reverse-proxy-for-agents.md), skill `new-tailscale-service` |
| add a host, or format its disk | [fleet/disk-formatting-for-agents.md](fleet/disk-formatting-for-agents.md), skill `new-host-config` |
| check credential expiry | [upkeep-and-admin/maintenance-schedule-for-agents.md](upkeep-and-admin/maintenance-schedule-for-agents.md), skill `maintenance-schedule` |
| run the fleet's periodic upkeep | [maintenance.md § Quick facts](upkeep-and-admin/maintenance.md#quick-facts) |
| work out which name/IP answers for what | [name-resolution.md § Quick facts](fleet/name-resolution.md#quick-facts) |
| reach or debug a cube service | [homelab/reaching-services.md § Quick facts](homelab/reaching-services.md#quick-facts) |
| cube lockout reset, Sunshine web UI, stream | [homelab/common-commands.md § Quick facts](homelab/common-commands.md#quick-facts) |
| cube's Claude Remote Control units | [homelab/claude-rc.md § Quick facts](homelab/claude-rc.md#quick-facts) |
| write or tighten a wiki page | [meta/styleguide-for-agents.md](meta/styleguide-for-agents.md), skills `wiki-sync`, `trim-docs`, `fact-hygiene` |
| fact-check docs or the book against the code | skills `wiki-fact-check`, `book-fact-check`; `just agent book-lint` |
| write a module | [config-structure/module-style-guide-for-agents.md](config-structure/module-style-guide-for-agents.md) |
| pick up an open, undiagnosed problem | [experiments/](experiments/), e.g. [durandal-auto-suspend-hang-for-agents.md](experiments/durandal-auto-suspend-hang-for-agents.md) |

## Cross-cutting pages

- [overview.md](overview.md) — 2-minute mental model.
- [fleet/hosts.md](fleet/hosts.md) — the roster.
- [fleet/durandal-gaming.md](fleet/durandal-gaming.md) — Steam (shared), Heroic +
  GameMode (durandal only), gamemode polkit group, worth-considering list.
- [config-structure/flake-parts.md](config-structure/flake-parts.md) → [config-structure/architecture.md](config-structure/architecture.md) —
  why flake-parts, then the category mechanism on top of it.
- [config-structure/module-files.md](config-structure/module-files.md) — a module file's shape and rules, and why
  (names from filenames, categories from folders).
- [meta/traps-and-skills.md](meta/traps-and-skills.md) — real past mistakes, and which skill holds each.
- [agent-lessons-learned.md](agent-lessons-learned.md) — every § as one line (rule,
  Home, Enforced), grouped by when it applies: read your task's group. By
  number: `ls wiki/agent-lessons-learned/43-*`. By file or area: `just agent
  lessons <path>`, from `.agents/lessons-map.toml`. No sibling.
- [meta/history.md](meta/history.md) — the index into the above.
- [config-structure/flake-parts-port-notes-for-agents.md](config-structure/flake-parts-port-notes-for-agents.md)
  — salvaged from the deleted `flake-parts` branch.
- [meta/open-threads-for-agents.md](meta/open-threads-for-agents.md) — loose ends are
  GitHub issues; labels, and the upstream-filing rule.
- [temporary-patches-and-hacks.md § Quick facts](upkeep-and-admin/temporary-patches-and-hacks.md#quick-facts)
  — workarounds for third-party bugs, each with its removal condition.

## Category reference

[config-structure/categories/00-INDEX.md](config-structure/categories/00-INDEX.md) — one page per category: contents, importers, traps. `shell-config` is the
one with a subdirectory ([blesh](config-structure/categories/shell-config/blesh-for-agents.md),
[carapace](config-structure/categories/shell-config/carapace.md)). `<name>-history.md` holds resolved incidents; rarely wanted.

## Homelab (usage, not config)

[homelab/00-INDEX.md](homelab/00-INDEX.md) — reaching
services, the forge
([practice loop](homelab/practice-environment.md) included),
[Grafana](homelab/grafana.md), go/ links, and what's
running but unfinished.

## Experiments (open questions)

[experiments/](experiments/) — one page per problem **instrumented but not yet
diagnosed**; "still measuring" is not settled config. Current:
[durandal-auto-suspend-hang-for-agents.md](experiments/durandal-auto-suspend-hang-for-agents.md) —
sleeps into S3 and will not wake without a PSU power cut. `suspend_stats`
reports those as `success`; s2idle and the BIOS are ruled out; `amdgpu.runpm=0`
tried 2026-09-14, failed; nothing under test, cause not found.
[tenacity-sd-reader-enumeration.md](experiments/tenacity-sd-reader-enumeration.md) —
reader `05e3:0764` on `usb2` port 1 fails to enumerate (error -62) on ~half of
6.18.57 boots and delays `pam_u2f` on the lock screen; suspect 6.18.56's 120ms
SS root hub hold; tabled, recheck on the next kernel bump. Also in `experiments/`: [durandal-suspend-instrumentation-state.md](experiments/durandal-suspend-instrumentation-state.md)
(what is running on durandal for the hang, each row with its check command) and
[a 2026-09-16 probe transcript](experiments/durandal-superio-probe-runbook-2026-09-16.md)
(historical, do not follow). On resolution the outcome moves to
[agent-lessons-learned.md](agent-lessons-learned.md) or the category page and the page goes.

## Rotting

Whichever change makes a page stale fixes it in the same change.
`just wiki-lint` checks the mechanical half; skill `wiki-sync` is the rest.

## See also

[00-INDEX.md](00-INDEX.md) · [meta/styleguide-for-agents.md](meta/styleguide-for-agents.md)
