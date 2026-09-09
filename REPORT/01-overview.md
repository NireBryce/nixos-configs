# 01 — Overview and top-to-bottom tour

_As of: 2026-09-08_

## What this repo is

`NireBryce/nixos-configs` is a personal fleet configuration: NixOS on three
machines, nix-darwin on one, Home Manager integrated into all four, built
with **flake-parts** and composed almost entirely by convention (directory
membership) rather than explicit import lists. It is explicitly not a
generalist template — `README.md` opens with "Do not install this blindly",
and that is not boilerplate: two of the three NixOS hosts delete `/root` on
every boot via impermanence.

The defining design choice: **membership is implicit and comes from the
directory**. There is no master list of modules to maintain; a `.nix` file
belongs to whatever category directory it is filed under, and adding a
module is a one-file change. The cost is that the tree is hard to browse
from a directory listing alone, which the repo compensates for with an
unusual amount of self-description: an agent-facing `AGENTS.md`, a
link-layer `wiki/`, per-mechanism docs in `flake/doc/`, and static checkers
that verify the docs' checkable claims against the tree.

## Safety picture (read before touching anything)

- `flake/modules/nire/impermanence/WARN-impermanence.nix` deletes the
  `/root` btrfs subvolume in initrd on every boot and requires a
  `root-blank` subvolume to exist. Imported by **`nire-durandal` and
  `nire-tenacity`**. `nire-cube` deliberately has a plain persistent root
  (`nireHost/cube-configuration.nix` documents why). Never assume "every
  host wipes root" or "no host does".
- Secrets are sops-nix (`flake/modules/nire/system/secrets/`);
  `secrets.yaml` is encrypted and committed — that is deliberate.
  `.sops.yaml` enrolls exactly four hosts (durandal, lysithea, tenacity,
  cube — verified in the file 2026-09-08).
- Roster source of truth: `flake/modules/nireHost/hosts.nix` and
  `wiki/hosts.md`. Switch/boot state is deliberately **not** recorded in
  the repo (it rots); answer "what is this host actually running" on the
  host with `just baseline` / `just diff-deployed`.

### The hosts (from `nireHost/hosts.nix`)

| Host | Class | Role | Wipes `/root` |
|---|---|---|---|
| `nire-durandal` | x86_64-linux | workstation | yes |
| `nire-tenacity` | x86_64-linux | handheld, Jovian/SteamOS | yes |
| `nire-cube` | x86_64-linux | workstation (GMKtec mini PC), runs the homelab stack | no |
| `nire-lysithea` | aarch64-darwin | laptop (the Mac) | n/a |

Four hosts total. (Two other host-like things were removed 2026-08-27/28 and
are recorded in `wiki/history.md`: `nire-lego`/`nire-installer`, and the
`nire-llm-sandbox` VM. `nire-galatea` appears in `.gitignore` and an ssh
authorized key but is not and was not a host of this flake.) The removed
`nire-installer` mechanism and the reusable `VMs/_lib/libvirt-vm.nix`
generator are documented at their removal sites in `hosts.nix`.

## Top-to-bottom tour

Everything below is at repo root unless prefixed.

| Path | What it is |
|---|---|
| `README.md` | Human entry point: warning, layout sketch, host list, pointer to the wiki index. |
| `AGENTS.md` | The agent working notes — canonical; `CLAUDE.md` is a symlink to it. Written by agents, corrected by Elly. The single most load-bearing file for anyone automating here. |
| `CLAUDE.md` | Symlink → `AGENTS.md`. |
| `flake/` | The entire flake. The root has **no** `flake.nix`; the flake entry point is `flake/flake.nix`, and every `just` recipe points at `flake/` explicitly. Holds `flake.nix`, `modules/` (all config), `scripts/` (16 tooling scripts), `doc/` (5 mechanism notes). |
| `flake/modules/` | Every piece of configuration, as flake-parts modules (see [02-architecture.md](02-architecture.md)). ~260 `.nix` files across areas `nire/`, `nireHost/`, `nirePackages/`, `nireUser/`, plus top-level `checks.nix`/`invariants.nix` and `_lib/`. |
| `flake/doc/` | Working notes next to the mechanisms they describe: `dirsAsCategory.md`, `flake-parts-rationale.md`, `disko-impermanence-layout.md`, `trailhead-home-manager-standalone.md`, `notes-and-fixes.md`. |
| `flake/scripts/` | The real logic behind the `just` interface (see [04](04-workflows-and-tooling.md)). `rebuild.sh`, `lint.py`, `modules.py`, `deployed-baseline.sh`, `diff-config.sh`, etc. |
| `.justfile` | The command interface. Deliberately logic-free: recipes are one line of dispatch to `flake/scripts/`; `just` lists one summary line each. |
| `wiki/` | 54 files. A **link layer over the docs above**, not a rewrite — with a machine checker (`just wiki-lint`) that keeps its checkable claims true. Index: `wiki/README.md`. |
| `.claude/` | The agent harness, committed: 20 skills in `.claude/skills/`, 3 guard hooks in `.claude/hooks/`, `settings.json`; `settings.local.json` is gitignored. |
| `.githooks/` | Two git hooks (lint ratchet pre-commit, provenance-trailer commit-msg), opt-in per clone via `just install-hooks`. |
| `.github/` | Two workflows (PR/push eval-check; weekly flake-lock PR), issue templates (YAML form), PR template. See [05](05-github-usage.md). |
| `.vscode/` | nixd LSP setup with formatting deliberately disabled (aligned-`=` columns survive), flake-aware option lookup. |
| `dev-shells/` | Two project *templates* (python, rust) with `create` recipes that scaffold a new project outside the repo using nix toolchains. |
| `wiki/scripts/` | `check_wiki.py` (the 11-subcheck wiki-lint), `wiki_churn.py`, `wiki_stale_refs.py` (report-only). |
| `_lab-notebook-nixos/` | Elly's personal Obsidian vault (dated agent-written notes, `human-written-docs/`). Tracked in git except `.trash/`; `.obsidian/workspace.json` is gitignored **but still tracked** — see [06](06-recommendations.md). |
| `bugs pending submission/` | Paste-ready drafts of *upstream* bug reports (nixpkgs, AMD, Jovian), each with a governance note: not filed, and not to be filed on the strength of the file existing. |
| `REPORT/` | This audit. |
| `result` | Nix build symlink, gitignored. |
| `.history/` | Editor history; gitignored (including a stale `nire-galatea` entry). |

## The documentation system (three tiers, plus two side rooms)

1. **Facts live next to the code they explain**: module-body comments,
   script docstrings, `flake/doc/`. No second copy is maintained.
2. **`wiki/` is an index over tier 1** — its own styleguide
   (`wiki/styleguide.md`) forbids restating facts that live elsewhere, and
   prescribes per-page `_Last modified` + `## Contents` scaffolding.
3. **Checkers keep the prose honest**: `wiki-lint` verifies imports lists,
   host tables, category index, recipe/skill mentions, sops enrollment,
   caddy routes, links, anchors, contents blocks, dates (11 subchecks);
   `just modules` catches module-name collisions and orphans; the lint
   ratchet (`flake/scripts/lint.py`) only lets finding counts fall.

The side rooms: `AGENTS.md` (the agent's operating manual — corrected by
Elly, so its load-bearing claims are trusted) and `_lab-notebook-nixos/`
(human-first notes; agent-ignorable by convention).

The philosophy in one line: **anti-duplication plus mechanical verification**
— a doc that can drift is either pointed at the thing it describes, checked
against it, or dated as a snapshot.

## Recommendations

See [06-recommendations.md](06-recommendations.md) for the full list with
priorities; the ones belonging to this page's scope:

- **R1 — `README.md`'s host list is stale**: it lists three hosts and omits
  `nire-lysithea`, and its Layout section says "`flake.nix` imports…"
  without mentioning the flake lives in `flake/` (the root has no
  `flake.nix`). Either fix the list or — better, matching the repo's own
  link-layer philosophy — replace the inline list with a pointer to
  `wiki/hosts.md` so it cannot rot again.
- **R2 — `AGENTS.md` says `ellyHomeManager` is "shared verbatim by all five
  hosts"**: there are four (hosts.nix, `.sops.yaml`, and the issue-template
  dropdown all say four). AGENTS.md is the file agents trust most; a wrong
  count in it is exactly the "stale claim" class the repo otherwise
  mechanizes away. `wiki-lint` checks AGENTS.md's sops claim but no subcheck
  counts hosts in prose — worth extending `check_wiki.py` rather than
  relying on re-reads.
