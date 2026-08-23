# Architecture & module system

For what's actually inside each individual category — members, which hosts
import it, category-specific traps — see the [category reference](categories/README.md)
instead of this page; this page is the mechanism, not the inventory.

## The core mechanism

- **[`../flake/doc/dirsAsCategory.md`](<../flake/doc/dirsAsCategory.md>)** —
  the load-bearing one. Every `.nix` file under `flake/modules/` is a
  flake-parts module (`flake.modules.<class>.<name> = ...`), and which
  category it belongs to is derived from the directory it's filed in, not
  declared explicitly. Read this before touching any `dirsAsCategory.nix`.
- **[`../CLAUDE.md`](../CLAUDE.md), Architecture section** — the prose
  overview: `import-tree`, entry points that sit outside every category tree
  (`modules/checks.nix`, `nireHost/hosts.nix`, the per-host configs,
  `nireUser/elly-home-manager.nix`), and which categories aren't imported by
  every host (`virtualization` is the running example — libvirt on
  workstations, deliberately absent on the handhelds).
- **Skill `new-flake-module`** (`.claude/skills/new-flake-module/SKILL.md`)
  — the traps in *writing* one: `flake.modules` can't live inside
  `perSystem`, a module's name comes from its filename so a rename can
  silently drop it from its category, two modules with the same name merge
  rather than conflict, and module classes aren't validated until the import
  site fails.

## Home Manager integration

- **[`../flake/doc/trailhead-home-manager-standalone.md`](<../flake/doc/trailhead-home-manager-standalone.md>)**
  — HM is wired in from the NixOS side (`useGlobalPkgs`/`useUserPackages`),
  not as a standalone `homeConfigurations` output. This doc is the trailhead
  back to standalone if that's ever wanted.
- **Skill `home-manager-dotfiles`**
  (`.claude/skills/home-manager-dotfiles/SKILL.md`) — traps specific to
  shell/dotfile modules: `home.file.<n>.text` and `home.sessionPath`
  concatenate rather than override across modules, reading a generated
  dotfile back has false negatives, and shell rc ordering
  (`mkBefore` → `mkOrder 550` → plugins → unordered) silently orphaned a
  hand-written `starship init` once.

## Package modules

- **Skill `nirepackages-platform-support`**
  (`.claude/skills/nirepackages-platform-support/SKILL.md`) — the two
  different questions that both show up as an `isDarwin` guard: can nixpkgs
  build it on darwin at all (automatic, from `meta.platforms`) vs. does
  Homebrew already install it on lysithea (never automatic — `just available
  --duplicates` finds the overlap). Worked examples: `vicinae.nix`,
  `obsidian.nix`.
- **[`../flake/scripts/mkPkgModule.md`](<../flake/scripts/mkPkgModule.md>)**
  — a trailhead, not a conversion: a generator exists for the
  single-package `home.packages` wrapper shape ~70 files under
  `nirePackages/` already share by hand, but nothing calls it yet. Explains
  why it's safe to sit unused and what adopting it would cost.
- **[`../flake/modules/nirePackages/idea.md`](<../flake/modules/nirePackages/idea.md>)**
  — one-line open idea: consider migrating more unconfigured packages from
  Home Manager to plain `nix`/`environment.systemPackages`. Not decided,
  not acted on.

## Related, easy to get backwards

Containers and VMs are separate categories here, and "virtualization" means
only the VM one (`nire/virtualization/`: libvirt, virt-tools,
vm-networking — optional, workstation-only). Podman/distrobox live in
[`nire/containers/`](categories/containers.md) — its own category since
2026-08-22 (moved out of `nire/system/containers/`), imported explicitly by
all four NixOS hosts rather than reaching them through `system`. See
[`../CLAUDE.md`](../CLAUDE.md)'s Architecture section for the file that's
been renamed twice now and why a stale memory of "virtualization is the
podman one" is exactly backwards regardless of which name you're picturing.
