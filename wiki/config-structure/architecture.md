# Architecture & module system

_Last modified: 2026-10-28_

`flake.nix` is a manifest: it reads every `.nix` file under `flake/modules/`
and fills `flake.modules.<class>.<name>` from them. A folder holding modules
is a category, and a host includes categories by name. For why the repo uses
flake-parts, see [flake-parts.md](flake-parts.md). For one category's
members, importing hosts and traps, see the
[category reference](categories/00-INDEX.md).

## Contents

- [Quick facts](#quick-facts)
- [The core mechanism](#the-core-mechanism)
- [The layout at a glance](#the-layout-at-a-glance)
- [Home Manager integration](#home-manager-integration)
- [Package modules](#package-modules)
- [Related, easy to get backwards](#related-easy-to-get-backwards)

## Quick facts

The mechanism in one table; the sections below link the reasoning.

| what | where / how |
|---|---|
| a module | a `.nix` under `flake/modules/` keyed by class (`{ nixos = …; }`); its name is its filename; dirs-as-categories (a flake input) turns it into `flake.modules.<class>.<name>` -- [module-files.md](module-files.md) |
| a class | the module system the config is for: `nixos`, `darwin`, `homeManager` |
| a category | a folder with a subfolder holding modules (or `folderIsCategory`); includes every module beneath it, nested categories included; hosts `includes` categories by name |
| the rules | the `dirs-as-categories` input (`flake/flake.nix`); its `doc/convention.md`, and [module-files.md](module-files.md) for this repo |
| membership as data | `nix eval --json ./flake#moduleGraph` |
| checks | evaluation refuses repeated names, unknown keys and unknown `includes`; `just modules`: orphans, untracked, drift (`nix flake check`'s `module-orphans` fails only when built) |
| diagrams | `just module-graph tree`, `hosts`, `dot`, `html` (`--category`, `--depth`, `--wrap`); the flake-module-graph input |
| Home Manager | integrated through NixOS, no `homeConfigurations`; `just switch` applies both |

## The core mechanism

- **[module-files.md](module-files.md)** — the load-bearing one. A module
  file is keyed by class and named after its file, and which category it
  belongs to is derived from the folder it's filed in, not declared. The
  `dirs-as-categories` flake input applies those rules and publishes what it
  built as data: `nix eval --json ./flake#moduleGraph` (categories, modules
  and their classes, `includes`, `enables`).
  [`../../flake/doc/dirsAsCategory.md`](<../../flake/doc/dirsAsCategory.md>) is
  the shim-based design it replaced on 2026-10-16, kept as history.
- **[`../../CLAUDE.md`](../../CLAUDE.md), Architecture section** — the prose
  overview: `dirs-as-categories`, entry points that sit outside every category
  (`host-config/hosts.nix`, the per-host configs,
  `users-config/elly-home-manager.nix`), and which categories aren't imported by
  every host (`virtualization` is the running example, deliberately absent on the
  handhelds — see [`categories/virtualization.md`](categories/virtualization.md)
  for which hosts import it).
- **[where-modules-go.md](where-modules-go.md)** — which of the three
  places a module belongs in: the shared tree (`general-config/`,
  `packages-config/`), a host's directory under `host-config/`, or a
  user's under `users-config/` — and the naming rule that goes with each.
- **Skill `new-flake-module`** (`.agents/skills/new-flake-module/SKILL.md`)
  — the traps in *writing* one: a module's name is its filename so a
  rename renames it, a repeated name stops evaluation (it used to merge
  silently), and a new subfolder can make a folder a category.

## The layout at a glance

The top of the tree, drawn from the files: each area directory, then the
categories directly in it. `n h d` are the classes a category carries
(nixos, homeManager, darwin) and the number is how many modules it holds,
nested categories included. Per-category and per-host diagrams are
on-demand, not committed: `just module-graph tree --category homelab`,
`just module-graph hosts`, `dot` for Graphviz
(`just module-graph dot --view hosts`), and `html` for an interactive page
of the hosts view (`just module-graph html > modules.html`): click hosts to
show only what they import.

Every diagram uses one colour standard, keyed on what a host can include:

- **Blue, rounded: an importable category.** A host can include it by
  name. An edge into one is dotted:
  it is importable alone and also collected by the category above it.
  A category that holds nested categories (`development`, `homelab`) is a
  pale blue box around them instead of a card, titled with its name,
  classes and module count; edges into it end at the box.
- **Slate, square-cornered (a folder in Graphviz): an implicit folder.** A
  plain directory inside a category; its modules arrive only through that
  category.
- **White: a module.** Also when a host names one directly (`kde-desktop`):
  importable means a category, never a single module.
- **Outline overlays on a category:** dashed when it is reached only
  through modules a host names one by one; red when no host imports it.

The hosts view runs top-down: the host's and user's own directories
(`host-config/<host>/`, `users-config/<user>/`) sit above the hosts, and
the shared categories they import below, wrapped into rows
(`--wrap N` sets the width), each host's edges in its own colour (never blue or red). In
Mermaid an edge up into the top row is a plain line, not an arrow.

<!-- generated:module-layout -- from the categories under flake/modules/, drawn by the flake-module-graph input, by `just wiki-gen`; change the source, not this table -->

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontFamily": "ui-sans-serif, system-ui, sans-serif", "fontSize": "14px", "lineColor": "#94a3b8"}, "flowchart": {"curve": "basis", "nodeSpacing": 24, "rankSpacing": 80, "padding": 14}}}%%
flowchart LR
    subgraph g0["users-config"]
        n27("<b>elly/</b><br/><i>n h d · 4</i>")
    end
    subgraph g1["packages-config"]
        n20("<b>development/</b><br/><i>n h · 16</i>")
        n21("<b>editors/</b><br/><i>n h · 3</i>")
        n22("<b>gui-other/</b><br/><i>h · 18</i>")
        n23("<b>linux-utils/</b><br/><i>h · 17</i>")
        n24("<b>nix-utils/</b><br/><i>n h · 4</i>")
        n25("<b>shell-apps/</b><br/><i>n h · 40</i>")
        n26("<b>terminals/</b><br/><i>h · 3</i>")
    end
    subgraph g2["host-config"]
        n16("<b>cube/</b><br/><i>n · 10</i>")
        n17("<b>durandal/</b><br/><i>n · 8</i>")
        n18("<b>lysithea/</b><br/><i>d · 2</i>")
        n19("<b>tenacity/</b><br/><i>n h · 11</i>")
    end
    subgraph g3["homelab-config"]
        n15("<b>homelab/</b><br/><i>n · 19</i>")
    end
    subgraph g4["hardware-config"]
        n13("<b>hardware/</b><br/><i>n · 8</i>")
        n14("<b>peripherals/</b><br/><i>n · 2</i>")
    end
    subgraph g5["general-config"]
        n6("<b>boot/</b><br/><i>n · 3</i>")
        n7("<b>desktop-env/</b><br/><i>n · 4</i>")
        n8("<b>impermanence/</b><br/><i>n h · 2</i>")
        n9("<b>macos/</b><br/><i>d · 3</i>")
        n10("<b>nix/</b><br/><i>n h d · 2</i>")
        n11("<b>shell-config/</b><br/><i>n h · 4</i>")
        n12("<b>system/</b><br/><i>n h d · 38</i>")
    end
    style g0 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    style g1 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    style g2 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    style g3 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    style g4 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    style g5 fill:#f8fafc,stroke:#cbd5e1,color:#64748b
    classDef area fill:#f8fafc,stroke:#cbd5e1,color:#1e293b,stroke-width:1.5px
    classDef category fill:#dbeafe,stroke:#2563eb,color:#1e293b,stroke-width:1.5px
    classDef folder fill:#f1f5f9,stroke:#94a3b8,color:#1e293b,stroke-width:1.5px
    classDef module fill:#ffffff,stroke:#94a3b8,color:#1e293b,stroke-width:1.5px
    classDef aggregate fill:#ffffff,stroke:#f59e0b,color:#1e293b,stroke-width:1.5px
    classDef missing fill:#fee2e2,stroke:#ef4444,color:#1e293b,stroke-width:1.5px
    classDef orphan fill:#fff1f2,stroke:#e11d48,color:#1e293b,stroke-width:2.5px
    classDef bymodule stroke-dasharray:5 3
    class n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16,n17,n18,n19,n20,n21,n22,n23,n24,n25,n26,n27 category
    class n7 bymodule
```

<!-- /generated -->

## Home Manager integration

- **[`../../flake/doc/trailhead-home-manager-standalone.md`](<../../flake/doc/trailhead-home-manager-standalone.md>)**
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
only the VM one (`homelab-config/homelab/virtualization/`: libvirt,
libvirt-persist, virt-tools, vm-egress-dns, vm-networking — cube only). Podman/distrobox live in
[`homelab-config/homelab/containers/`](categories/containers.md), its own category
since 2026-08-22, nested under the `homelab` umbrella since 2026-08-27 —
imported by cube only (durandal dropped it 2026-08-27, same day as
`virtualization`; tenacity 2026-09-26). See
[`categories/homelab.md`](categories/homelab.md) and
`.agents/rules/homelab.md`. A stale memory of "virtualization is the podman one"
is exactly backwards.
