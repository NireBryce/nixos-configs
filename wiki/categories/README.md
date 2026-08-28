# Category reference

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

| Category | Directory | Class(es) | Members | Imported by |
|---|---|---|---|---|
| [backup](backup.md) | `nire/homelab/backup/` | nixos | 1 | cube only |
| [boot](boot.md) | `nire/boot/` | nixos | 1 | all 3 NixOS hosts |
| [containers](containers.md) | `nire/homelab/containers/` | nixos | 1 | tenacity, cube (not durandal) |
| [desktop-env](desktop-env.md) | `nire/desktop-env/` | nixos, homeManager | 4 | never imported whole — hosts take `jovian` or `kde-desktop` by name |
| [git-forge](git-forge.md) | `nire/homelab/git-forge/` | nixos | 1 | cube only |
| [hardware](hardware.md) | `nire/hardware/` (+ nested `amd`) | nixos | 2 | all 3 NixOS hosts |
| [homelab](homelab.md) | `nire/homelab/` (+ 8 nested) | nixos | 15 | cube only |
| [impermanence](impermanence.md) | `nire/impermanence/` | nixos, homeManager | 2 | durandal, tenacity (not cube) |
| [landing](landing.md) | `nire/homelab/landing/` | nixos | 1 | cube only |
| [macos](macos.md) | `nire/macos/` | darwin | 3 | lysithea |
| [monitoring](monitoring.md) | `nire/homelab/monitoring/` | nixos | 5 | cube only |
| [nix](nix.md) | `nire/nix/` | nixos, homeManager, darwin | 2 | all 4 hosts |
| [peripherals](peripherals.md) | `nire/peripherals/` | nixos | 2 | all 3 NixOS hosts |
| [reverse-proxy](reverse-proxy.md) | `nire/homelab/reverse-proxy/` | nixos | 1 | cube only |
| [shell-config](shell-config/README.md) | `nire/shell-config/` | nixos, homeManager | 4 | all 3 NixOS hosts directly; reaches lysithea via `ellyHomeManager` |
| [shortlinks](shortlinks.md) | `nire/homelab/shortlinks/` | nixos | 1 | cube only |
| [system](system.md) | `nire/system/` | nixos, homeManager, darwin | 37, in ~19 subdirectories | all 3 NixOS hosts + lysithea (partially) |
| [virtualization](virtualization.md) | `nire/homelab/virtualization/` | nixos | 4 | cube only (not durandal, not the handheld) |
| [elly](elly.md) | `nireUser/elly/` | nixos, homeManager | 4 | all 4 hosts |

"Members" counts real `.nix` files under the category directory, excluding
`dirsAsCategory.nix` itself and anything under a `_`-prefixed path.

`shell-config` is the one category page that's grown into its own
directory rather than a single file — `shell-config/README.md` is the
category article proper, and `shell-config/blesh.md` /
`shell-config/carapace.md` sit alongside it as deep-dives on two specific
members that turned out to have enough to say for their own pages. If
another category's page grows a deep-dive worth splitting out, this is the
precedent to follow — see [../styleguide.md](../styleguide.md) for the
general rule (when it applies, naming, and why not to nest further).
