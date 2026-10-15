# Architecture & module system

_Last modified: 2026-10-15_

For *why* this repo runs flake-parts at all, see [flake-parts.md](flake-parts.md)
first — this page is the mechanism built on top of that, not the reason for
it. For what's actually inside each individual category — members, which
hosts import it, category-specific traps — see the
[category reference](categories/00-INDEX.md) instead of this page; this page
is the mechanism, not the inventory.

## Contents

- [The core mechanism](#the-core-mechanism)
- [The layout at a glance](#the-layout-at-a-glance)
- [Home Manager integration](#home-manager-integration)
- [Package modules](#package-modules)
- [Related, easy to get backwards](#related-easy-to-get-backwards)

## The core mechanism

- **[`../flake/doc/dirsAsCategory.md`](<../flake/doc/dirsAsCategory.md>)** —
  the load-bearing one. Every `.nix` file under `flake/modules/` is a
  flake-parts module (`flake.modules.<class>.<name> = ...`), and which
  category it belongs to is derived from the directory it's filed in, not
  declared explicitly. Read this before touching any `dirsAsCategory.nix`.
  What each category collects is also published as data:
  `nix eval --json ./flake#categoryGraph` (its directory, the module files
  it collects itself, and the categories nested in it).
- **[`../CLAUDE.md`](../CLAUDE.md), Architecture section** — the prose
  overview: `import-tree`, entry points that sit outside every category tree
  (`modules/checks.nix`, `host-config/hosts.nix`, the per-host configs,
  `users-config/elly-home-manager.nix`), and which categories aren't imported by
  every host (`virtualization` is the running example — cube only as of
  2026-08-27, deliberately absent on the handhelds and, since that date, on
  durandal too — see [`categories/virtualization.md`](categories/virtualization.md)).
- **[where-modules-go.md](where-modules-go.md)** — which of the three
  places a module belongs in: the shared tree (`general-config/`,
  `packages-config/`), a host's directory under `host-config/`, or a
  user's under `users-config/` — and the naming rule that goes with each.
- **Skill `new-flake-module`** (`.agents/skills/new-flake-module/SKILL.md`)
  — the traps in *writing* one: `flake.modules` can't live inside
  `perSystem`, a module's name comes from its filename so a rename can
  silently drop it from its category, two modules with the same name merge
  rather than conflict, and module classes aren't validated until the import
  site fails.

## The layout at a glance

The top of the tree, drawn from the files: each area directory, then the
categories directly in it. `n h d` are the classes a category carries
(nixos, homeManager, darwin) and the number is how many modules it holds,
nested categories included. Per-category and per-host diagrams are
on-demand, not committed: `just module-graph tree --category homelab`,
`just module-graph hosts`, and `dot` for Graphviz
(`just module-graph dot --view hosts`).

Every diagram uses one colour standard, keyed on the `dirsAsCategory.nix`
criterion:

- **Blue, rounded: an importable category.** The directory holds a
  `dirsAsCategory.nix`, so a host can name it. An edge into one is dotted:
  it is importable alone and also collected by the category above it.
- **Slate, square-cornered (a folder in Graphviz): an implicit folder.** A
  plain directory inside a category; its modules arrive only through that
  category.
- **White: a module.** Also when a host names one directly (`kde-desktop`):
  importable means a category, never a single module.
- **Outline overlays on a category:** dashed when it is reached only
  through modules a host names one by one; red when no host imports it.

<!-- generated:module-layout -- from the dirsAsCategory.nix tree under flake/modules/, drawn by flake/scripts/module-graph.py, by `just wiki-gen`; change the source, not this table -->

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontFamily": "ui-sans-serif, system-ui, sans-serif", "fontSize": "14px", "lineColor": "#94a3b8"}, "flowchart": {"curve": "basis", "nodeSpacing": 24, "rankSpacing": 80, "padding": 14}}}%%
flowchart LR
    subgraph g3["users-config"]
        n25("<b>elly/</b><br/><i>n h d · 4</i>")
    end
    style g3 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    subgraph g2["packages-config"]
        n18("<b>development/</b><br/><i>n h · 17</i>")
        n19("<b>editors/</b><br/><i>n h · 3</i>")
        n20("<b>gui-other/</b><br/><i>h · 20</i>")
        n21("<b>linux-utils/</b><br/><i>h · 17</i>")
        n22("<b>nix-utils/</b><br/><i>n h · 4</i>")
        n23("<b>shell-apps/</b><br/><i>n h · 40</i>")
        n24("<b>terminals/</b><br/><i>h · 3</i>")
    end
    style g2 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    subgraph g1["host-config"]
        n14("<b>cube/</b><br/><i>n · 9</i>")
        n15("<b>durandal/</b><br/><i>n · 6</i>")
        n16("<b>lysithea/</b><br/><i>d · 2</i>")
        n17("<b>tenacity/</b><br/><i>n h · 11</i>")
    end
    style g1 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    subgraph g0["general-config"]
        n4("<b>boot/</b><br/><i>n · 2</i>")
        n5("<b>desktop-env/</b><br/><i>n · 4</i>")
        n6("<b>hardware/</b><br/><i>n · 2</i>")
        n7("<b>homelab/</b><br/><i>n · 21</i>")
        n8("<b>impermanence/</b><br/><i>n h · 2</i>")
        n9("<b>macos/</b><br/><i>d · 3</i>")
        n10("<b>nix/</b><br/><i>n h d · 2</i>")
        n11("<b>peripherals/</b><br/><i>n · 2</i>")
        n12("<b>shell-config/</b><br/><i>n h · 4</i>")
        n13("<b>system/</b><br/><i>n h d · 44</i>")
    end
    style g0 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    classDef area fill:#f8fafc,stroke:#cbd5e1,color:#1e293b,stroke-width:1.5px
    classDef category fill:#dbeafe,stroke:#2563eb,color:#1e293b,stroke-width:1.5px
    classDef folder fill:#f1f5f9,stroke:#94a3b8,color:#1e293b,stroke-width:1.5px
    classDef module fill:#ffffff,stroke:#94a3b8,color:#1e293b,stroke-width:1.5px
    classDef aggregate fill:#ffffff,stroke:#f59e0b,color:#1e293b,stroke-width:1.5px
    classDef missing fill:#fee2e2,stroke:#ef4444,color:#1e293b,stroke-width:1.5px
    classDef orphan fill:#fff1f2,stroke:#e11d48,color:#1e293b,stroke-width:2.5px
    classDef bymodule stroke-dasharray:5 3
    classDef merges stroke:#e11d48,stroke-width:2.5px
    class n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16,n17,n18,n19,n20,n21,n22,n23,n24,n25 category
    class n5 bymodule
```

<!-- /generated -->

## Home Manager integration

- **[`../flake/doc/trailhead-home-manager-standalone.md`](<../flake/doc/trailhead-home-manager-standalone.md>)**
  — HM is wired in from the NixOS side (`useGlobalPkgs`/`useUserPackages`),
  not as a standalone `homeConfigurations` output. This doc is the trailhead
  back to standalone if that's ever wanted.
- **Skill `home-manager-dotfiles`**
  (`.agents/skills/home-manager-dotfiles/SKILL.md`) — traps specific to
  shell/dotfile modules: `home.file.<n>.text` and `home.sessionPath`
  concatenate rather than override across modules, reading a generated
  dotfile back has false negatives, and shell rc ordering
  (`mkBefore` → `mkOrder 550` → plugins → unordered) silently orphaned a
  hand-written `starship init` once.

## Package modules

- **Skill `package-platform-support`**
  (`.agents/skills/package-platform-support/SKILL.md`) — the two
  different questions that both show up as an `isDarwin` guard: can nixpkgs
  build it on darwin at all (automatic, from `meta.platforms`) vs. does
  Homebrew already install it on lysithea (never automatic — `just available
  --duplicates` finds the overlap). Worked examples: `vicinae.nix`,
  `obsidian.nix`.
## Related, easy to get backwards

Containers and VMs are separate categories here, and "virtualization" means
only the VM one (`general-config/homelab/virtualization/`: libvirt, virt-tools,
vm-networking — optional, cube only). Podman/distrobox live in
[`general-config/homelab/containers/`](categories/containers.md), its own category
since 2026-08-22, nested under the `homelab` umbrella since 2026-08-27 —
imported by cube only (durandal dropped it 2026-08-27, same day as
`virtualization`; tenacity 2026-09-26). See
[`categories/homelab.md`](categories/homelab.md) and
`.agents/rules/homelab.md`. A stale memory of "virtualization is the podman one"
is exactly backwards.
