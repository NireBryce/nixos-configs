# Category reference

## Contents

- [Index](#index)
- [Usage pages](#usage-pages)

One article per real category — a directory holding its own
`dirsAsCategory.nix` under `flake/modules/`. See
[../architecture.md](../architecture.md) for the mechanism itself; these
pages are the "what's actually in it, and why is it shaped this way" detail
for each one, at the same what/why/traps depth as the rest of this wiki.

Scoped to the `nire/*` system-ish categories plus `nireUser/elly` — 19
articles. Not covered here, deliberately:

- **`nirePackages/*` subcategories** (`editors`, `terminals`, `gui-other`,
  `linux-utils`, `nix-utils`, `shell-apps`, `development`, …) — mostly
  single-package wrapper files that are already self-explanatory from their
  filename and a glance at the file itself; see
  [../architecture.md](../architecture.md)'s package-modules section instead.
- **`nireHost/*` per-host bundles** (`durandal`, `tenacity`, `cube`,
  `lysithea`) — these are host definitions, not conceptual categories; see
  [../hosts.md](../hosts.md).

## Index

Two tables, split by shape rather than alphabetically: categories any host
might import directly, and the `nire/homelab/` nested set that's cube-only
by construction (see [homelab](homelab.md)). Same four columns in both —
the split is presentation only, nothing about the schema changes.

### System categories

| Category | Directory | Class(es) | Imported by |
|---|---|---|---|
| [boot](boot.md) | `nire/boot/` | nixos | all 3 NixOS hosts |
| [desktop-env](desktop-env.md) | `nire/desktop-env/` | nixos | never imported whole — hosts take `jovian` or `kde-desktop` by name |
| [hardware](hardware.md) | `nire/hardware/` (+ nested `amd`) | nixos | all 3 NixOS hosts |
| [impermanence](impermanence.md) | `nire/impermanence/` | nixos, homeManager | durandal, tenacity (not cube) |
| [macos](macos.md) | `nire/macos/` | darwin | lysithea |
| [nix](nix.md) | `nire/nix/` | nixos, homeManager, darwin | all 4 hosts |
| [peripherals](peripherals.md) | `nire/peripherals/` | nixos | all 3 NixOS hosts |
| [shell-config](shell-config/README.md) | `nire/shell-config/` | nixos, homeManager | all 3 NixOS hosts directly; reaches lysithea via `ellyHomeManager` |
| [system](system.md) | `nire/system/` | nixos, homeManager, darwin | all 3 NixOS hosts + lysithea (partially) |
| [elly](elly.md) | `nireUser/elly/` | nixos, homeManager, darwin | all 4 hosts |

### Homelab categories

Nested under `nire/homelab/`, cube-only — see [homelab](homelab.md) for the
umbrella mechanism, and the [Usage pages](#usage-pages) table below for the
matching "how do I use this, not configure it" page where one exists.

| Category | Directory | Class(es) | Imported by |
|---|---|---|---|
| [backup](backup.md) | `nire/homelab/backup/` | nixos | cube only |
| [containers](containers.md) | `nire/homelab/containers/` | nixos | tenacity, cube (not durandal) |
| [git-forge](git-forge.md) | `nire/homelab/git-forge/` | nixos | cube only |
| [homelab](homelab.md) | `nire/homelab/` (+ 8 nested) | nixos | cube only |
| [landing](landing.md) | `nire/homelab/landing/` | nixos | cube only |
| [monitoring](monitoring.md) | `nire/homelab/monitoring/` | nixos | cube only |
| [reverse-proxy](reverse-proxy.md) | `nire/homelab/reverse-proxy/` | nixos | cube only |
| [shortlinks](shortlinks.md) | `nire/homelab/shortlinks/` | nixos | cube only |
| [virtualization](virtualization.md) | `nire/homelab/virtualization/` | nixos | cube only (not durandal, not the handheld) |

## Usage pages

The homelab categories above are configuration; these are the matching
usage-tier pages, per [homelab/README.md](../homelab/README.md)'s
config-vs-usage split. "—" means no service exists to write one about yet.

| Category | Usage page |
|---|---|
| backup | [homelab/backup-runbook.md](../homelab/backup-runbook.md) (+ [rustic.md](../homelab/rustic.md) for browsing/restoring) |
| containers | — (podman/distrobox, no fleet-facing service) |
| git-forge | [homelab/forgejo.md](../homelab/forgejo.md) |
| landing | [homelab/reaching-services.md](../homelab/reaching-services.md) (glance is the front page itself, not a separate page) |
| monitoring | not yet written up — see [homelab/README.md](../homelab/README.md)'s "Also running, not yet written up" |
| reverse-proxy | [homelab/reaching-services.md](../homelab/reaching-services.md) (the arrangement all the others sit behind) |
| shortlinks | [homelab/golinks.md](../homelab/golinks.md) |
| virtualization | — (`nire-llm-sandbox` removed 2026-08-28; see the category's own page) |

No per-category file count here on purpose (removed 2026-08-29, along with
`system.md`'s matching "N files across M subdirectories" line and the
`check_wiki.py` machinery that verified it) — read the category's own
directory for the current file list rather than trusting a number here;
same reasoning this repo already applies to host enrollment lists
(CLAUDE.md, Safety: "read the file directly ... rather than trusting a
count here").

`shell-config` is the one category page that's grown into its own
directory rather than a single file — `shell-config/README.md` is the
category article proper, and `shell-config/blesh.md` /
`shell-config/carapace.md` sit alongside it as deep-dives on two specific
members that turned out to have enough to say for their own pages. If
another category's page grows a deep-dive worth splitting out, this is the
precedent to follow — see [../styleguide.md](../styleguide.md) for the
general rule (when it applies, naming, and why not to nest further).
