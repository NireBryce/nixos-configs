# Wiki index, for agents

_Last modified: 2026-10-01_

Condensed from [00-INDEX.md](00-INDEX.md). Routing only.

`flake/` is browsed by file tree ([architecture.md](architecture.md)). `CLAUDE.md`
is the cold-start read; this page says which file holds the answer. Pages with a
`-for-agents` sibling are listed by the sibling; load the human page only for the *why*.
A page without one opens with `## Quick facts` — linked there.

## By task

| Task | Read |
|---|---|
| add, rename, or wire a flake-parts module | [architecture.md](architecture.md), skill `new-flake-module` |
| place a new module: shared / host / user | [where-modules-go.md](where-modules-go.md) |
| touch impermanence or initrd | [impermanence-and-secrets.md](impermanence-and-secrets.md), skill `impermanence-initrd` |
| add or platform-gate a package | [categories/00-INDEX.md](categories/00-INDEX.md), skill `package-platform-support` |
| add a package to a user's environment | skill `new-package` |
| land a change on `experimental` | [conventions.md](conventions.md), skill `ship` |
| work without clobbering another session | skill `use-a-worktree` |
| script a command pattern agents keep re-typing | skill `agent-scripts` |
| check whether a bug is already tracked | [open-threads-for-agents.md](open-threads-for-agents.md), skill `investigate-bug` |
| add a self-hosted service | [homelab/00-INDEX.md](homelab/00-INDEX.md), skill `new-homelab-service` |
| give a service its own `svc:` hostname | [categories/reverse-proxy-for-agents.md](categories/reverse-proxy-for-agents.md), skill `new-tailscale-service` |
| add a host, or format its disk | [disk-formatting-for-agents.md](disk-formatting-for-agents.md), skill `new-host-config` |
| check credential expiry | [maintenance-schedule-for-agents.md](maintenance-schedule-for-agents.md), skill `maintenance-schedule` |
| run the fleet's periodic upkeep | [maintenance.md § Quick facts](maintenance.md#quick-facts) |
| bump or retire a hand-pinned upstream package | skill `pinned-packages` |
| work out which name/IP answers for what | [name-resolution.md § Quick facts](name-resolution.md#quick-facts) |
| reach or debug a cube service | [homelab/reaching-services-for-agents.md](homelab/reaching-services-for-agents.md) |
| write or tighten a wiki page | [styleguide-for-agents.md](styleguide-for-agents.md), skills `wiki-sync`, `trim-docs`, `fact-hygiene` |
| write a module | [module-style-guide-for-agents.md](module-style-guide-for-agents.md) |
| pick up an open, undiagnosed problem | [experiments/](experiments/), e.g. [durandal-auto-suspend-hang-for-agents.md](experiments/durandal-auto-suspend-hang-for-agents.md) |

## Cross-cutting pages

- [overview.md](overview.md) — 2-minute mental model.
- [hosts.md](hosts.md) — the roster.
- [flake-parts.md](flake-parts.md) → [architecture.md](architecture.md) —
  why flake-parts, then the `dirsAsCategory` mechanism on top of it.
- [traps-and-skills.md](traps-and-skills.md) — real past mistakes, and which skill holds each.
- [lessons-learned.md](lessons-learned.md) — every § as one line (rule,
  Home, Enforced), grouped by when it applies: read your task's group. By
  number: `ls wiki/lessons-learned/43-*`. No sibling.
- [history.md](history.md) — the index into the above.
- [flake-parts-port-notes-for-agents.md](flake-parts-port-notes-for-agents.md)
  — salvaged from the deleted `flake-parts` branch.
- [open-threads-for-agents.md](open-threads-for-agents.md) — loose ends are
  GitHub issues; labels, and the upstream-filing rule.

## Category reference

[categories/00-INDEX.md](categories/00-INDEX.md) — one page per category: contents, importers, traps. `shell-config` is the
one with a subdirectory ([blesh](categories/shell-config/blesh-for-agents.md),
[carapace](categories/shell-config/carapace.md)). `<name>-history.md` holds resolved incidents; rarely wanted.

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
tried 2026-09-14, failed; nothing under test, cause not found. On resolution the outcome moves to
[lessons-learned.md](lessons-learned.md) or the category page and the page goes.

## Rotting

Whichever change makes a page stale fixes it in the same change.
`just wiki-lint` checks the mechanical half; skill `wiki-sync` is the rest.

## See also

[00-INDEX.md](00-INDEX.md) · [styleguide-for-agents.md](styleguide-for-agents.md)
