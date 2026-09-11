# Wiki index, for agents

_Last modified: 2026-09-11_

Condensed from [README.md](README.md), which keeps the orientation prose and
the "why a link layer, not a rewrite" reasoning. Routing only here.

`CLAUDE.md` is still the cold-start read. This page answers "which file
actually holds the answer". A page with a `-for-agents` sibling is listed by
that sibling; load the human page only for the *why*.

## By task

| Task | Read |
|---|---|
| add, rename, or wire a flake-parts module | [architecture.md](architecture.md), skill `new-flake-module` |
| touch impermanence or initrd | [impermanence-and-secrets.md](impermanence-and-secrets.md), skill `impermanence-initrd` |
| add or platform-gate a package | [categories/README.md](categories/README.md), skill `nirepackages-platform-support` |
| add a package to a user's environment | skill `new-package` |
| land a change on `experimental` | [conventions.md](conventions.md), skill `ship` |
| work without clobbering another session | skill `use-a-worktree` |
| check whether a bug is already tracked | [open-threads-for-agents.md](open-threads-for-agents.md), skill `investigate-bug` |
| add a self-hosted service | [homelab/README.md](homelab/README.md), skill `new-homelab-service` |
| give a service its own `svc:` hostname | [categories/reverse-proxy-for-agents.md](categories/reverse-proxy-for-agents.md), skill `new-tailscale-service` |
| add a host, or format its disk | [disk-formatting-for-agents.md](disk-formatting-for-agents.md), skill `new-host-config` |
| check credential expiry | [maintenance-schedule-for-agents.md](maintenance-schedule-for-agents.md), skill `maintenance-schedule` |
| reach or debug a cube service | [homelab/reaching-services-for-agents.md](homelab/reaching-services-for-agents.md) |
| write or tighten a wiki page | [styleguide-for-agents.md](styleguide-for-agents.md), skills `wiki-sync`, `trim-docs`, `fact-hygiene` |
| write a module | [module-style-guide-for-agents.md](module-style-guide-for-agents.md) |

## Cross-cutting pages

- [overview.md](overview.md) — 2-minute mental model.
- [hosts.md](hosts.md) — the roster, and what's actually been switched vs.
  only evaluated.
- [flake-parts.md](flake-parts.md) → [architecture.md](architecture.md) —
  why flake-parts, then the `dirsAsCategory` mechanism on top of it.
- [traps-and-skills.md](traps-and-skills.md) — mistakes that have actually
  happened here, and which skill holds each.
- [lessons-learned.md](lessons-learned.md) — §1–48, one line each, long
  entries broken out into `lessons-learned/`. **Located by § number** — grep
  `## 43\.`, don't read it front to back. Already agent-facing; no sibling.
- [history.md](history.md) — the index into the above.
- [flake-parts-port-notes-for-agents.md](flake-parts-port-notes-for-agents.md)
  — salvaged from the deleted `flake-parts` branch.
- [open-threads-for-agents.md](open-threads-for-agents.md) — pending reports,
  todos, things to look into.

## Category reference

[categories/README.md](categories/README.md) — one page per real category:
what's in it, which hosts import it, its own traps. `shell-config` is the
one with a subdirectory ([blesh](categories/shell-config/blesh-for-agents.md),
[carapace](categories/shell-config/carapace.md)). A `<name>-history.md`
sibling holds resolved incidents and is rarely what you want.

## Homelab (usage, not config)

[homelab/README.md](homelab/README.md) — reaching
services, the forge, go/ links, and what's running but unfinished.

## Rotting

Whichever change makes a page stale fixes it in the same change.
`just wiki-lint` checks the mechanical half; skill `wiki-sync` is the rest.

## See also

[README.md](README.md) · [styleguide-for-agents.md](styleguide-for-agents.md)
