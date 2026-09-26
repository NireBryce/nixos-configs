# Category reference

_Last modified: 2026-09-26_

One article per real category — a directory holding its own
`dirsAsCategory.nix` under `flake/modules/`. See
[../architecture.md](../architecture.md) for the mechanism itself; these
pages are the "what's actually in it, and why is it shaped this way" detail
for each one, at the same what/why/traps depth as the rest of this wiki.

Scoped to the `config-system/*` system-ish categories plus `users/elly` — 19
articles. Not covered here, deliberately:

- **`packages/*` subcategories** (`editors`, `terminals`, `gui-other`,
  `linux-utils`, `nix-utils`, `shell-apps`, `development`, …) — mostly
  single-package wrapper files that are already self-explanatory from their
  filename and a glance at the file itself; see
  [../architecture.md](../architecture.md)'s package-modules section instead.
- **`hosts/*` per-host bundles** (`durandal`, `tenacity`, `cube`,
  `lysithea`) — these are host definitions, not conceptual categories; see
  [../hosts.md](../hosts.md).

## Contents

- [Index](#index)
- [Usage pages](#usage-pages)

## Index

Two tables, split by shape rather than alphabetically: categories any host
might import directly, and the `config-system/homelab/` nested set that's cube-only
by construction (see [homelab](homelab.md)). Same four columns in both —
the split is presentation only, nothing about the schema changes.

### System categories

| Category | Directory | Class(es) | Imported by |
|---|---|---|---|
| [boot](boot.md) | `config-system/boot/` | nixos | all 3 NixOS hosts |
| [desktop-env](desktop-env.md) | `config-system/desktop-env/` | nixos | never imported whole — hosts take `jovian` or `kde-desktop` by name |
| [hardware](hardware.md) | `config-system/hardware/` (+ nested `amd`) | nixos | all 3 NixOS hosts |
| [impermanence](impermanence.md) | `config-system/impermanence/` | nixos, homeManager | durandal, tenacity (not cube) |
| [macos](macos.md) | `config-system/macos/` | darwin | lysithea |
| [nix](nix.md) | `config-system/nix/` | nixos, homeManager, darwin | all 4 hosts |
| [peripherals](peripherals.md) | `config-system/peripherals/` | nixos | all 3 NixOS hosts |
| [shell-config](shell-config/00-INDEX.md) | `config-system/shell-config/` | nixos, homeManager | all 3 NixOS hosts directly; reaches lysithea via `ellyHomeManager` |
| [system](system.md) | `config-system/system/` | nixos, homeManager, darwin | all 3 NixOS hosts + lysithea (partially) |
| [elly](elly.md) | `users/elly/` | nixos, homeManager, darwin | all 4 hosts |

### Homelab categories

Nested under `config-system/homelab/`, cube-only — see [homelab](homelab.md) for the
umbrella mechanism, and the [Usage pages](#usage-pages) table below for the
matching "how do I use this, not configure it" page where one exists.

| Category | Directory | Class(es) | Imported by |
|---|---|---|---|
| [backup](backup.md) | `config-system/homelab/backup/` | nixos | cube only |
| [containers](containers.md) | `config-system/homelab/containers/` | nixos | cube only |
| [git-forge](git-forge.md) | `config-system/homelab/git-forge/` | nixos | cube only |
| [homelab](homelab.md) | `config-system/homelab/` (+ 8 nested) | nixos | cube only |
| [landing](landing.md) | `config-system/homelab/landing/` | nixos | cube only |
| [monitoring](monitoring.md) | `config-system/homelab/monitoring/` | nixos | cube only |
| [reverse-proxy](reverse-proxy.md) | `config-system/homelab/reverse-proxy/` | nixos | cube only |
| [shortlinks](shortlinks.md) | `config-system/homelab/shortlinks/` | nixos | cube only |
| [virtualization](virtualization.md) | `config-system/homelab/virtualization/` | nixos | cube only (not durandal, not the handheld) |

## Usage pages

The homelab categories above are configuration; these are the matching
usage-tier pages, per [homelab/00-INDEX.md](../homelab/00-INDEX.md)'s
config-vs-usage split. "—" means no service exists to write one about yet.

| Category | Usage page |
|---|---|
| backup | [homelab/backup-runbook.md](../homelab/backup-runbook.md) (+ [rustic.md](../homelab/rustic.md) for browsing/restoring) |
| containers | — (podman/distrobox, no fleet-facing service) |
| git-forge | [homelab/forgejo.md](../homelab/forgejo.md) |
| landing | [homelab/reaching-services.md](../homelab/reaching-services.md) (homepage is the front page; glance beside it since 2026-09-13 for the evaluation) |
| monitoring | not yet written up — see [homelab/00-INDEX.md](../homelab/00-INDEX.md)'s "Also running, not yet written up" |
| reverse-proxy | [homelab/reaching-services.md](../homelab/reaching-services.md) (the arrangement all the others sit behind) |
| shortlinks | [homelab/creating-golinks.md](../homelab/creating-golinks.md) |
| virtualization | — (`nire-llm-sandbox` removed 2026-08-28; see the category's own page) |

No per-category file count here on purpose (removed 2026-08-29, with the
`check_wiki.py` machinery that verified it) — read the category's own
directory rather than trusting a number here.

`shell-config` is the one category grown into its own directory —
`shell-config/00-INDEX.md` is the category article proper, with `blesh.md` /
`carapace.md` as deep-dives on two specific members. If another category
grows a deep-dive worth splitting out, that's the precedent — see
[../styleguide.md](../styleguide.md) for the general rule.
