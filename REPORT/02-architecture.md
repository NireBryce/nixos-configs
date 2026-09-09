# 02 — Flake architecture

_As of: 2026-09-08. Counts are from the tree on that date: 263 `.nix` files
under `flake/modules/` (97 `nire/`, 129 `nirePackages/`, 28 `nireHost/`,
6 `nireUser/`, plus top-level `checks.nix`, `invariants.nix`, and
`_lib/category-collector.nix`), 39 of them two-line category shims._

## The entry point is a manifest

`flake/flake.nix` (note: **in `flake/`, not at repo root** — the root has no
`flake.nix`, which is why every `just` recipe says `cd flake`) contains no
configuration. It does four things:

1. `inputs.flake-parts.lib.mkFlake` wraps the whole flake in flake-parts.
2. Imports four modules:
   - `inputs.flake-parts.flakeModules.modules` — declares the
     `flake.modules.<class>.<name>` option every module in the tree writes
     into. This one option is the repo's organizing principle.
   - `inputs.darwin.flakeModules.default` — declares `darwinConfigurations`.
   - `(inputs.import-tree ./modules)` — recursively imports **every `.nix`
     file** under `flake/modules/`. No path is wired by hand anywhere.
   - `inputs.flake-parts.flakeModules.touchup` with
     `touchup.attr.formatter.enable = false` — drops the `formatter` output
     entirely. Without it `nix flake check` errors on a fresh clone because
     this flake never defines `perSystem.formatter` (full post-mortem in a
     comment at the import site, `flake/flake.nix:18-38`). Consistent with
     `nix fmt` being deliberately unwired — a formatter would flatten the
     aligned-`=` columns (see [03](03-conventions-and-style.md)).
3. Sets `systems = [ "x86_64-linux" "aarch64-darwin" ]`.
4. Declares inputs. Convention: every input pins its nixpkgs via
   `inputs.<x>.nixpkgs.follows = "nixpkgs"` so the lock holds **one**
   nixpkgs. `nixpkgs` itself tracks `nixos-unstable`; `home-manager` and
   `darwin` track `master` — the lock file is the pin, refreshed weekly by
   automation (see [05](05-github-usage.md)). Commented-out inputs
   (`den`, `flake-aspects`, `systems`) mark the abandoned "dendritic"
   toolchain direction.

## Every file under `modules/` is a flake-parts module

`import-tree` imports all of them, so each must evaluate to something the
flake-parts module system accepts — top level
`{ flake.modules.<class>.<name> = …; }` or similar, never a bare NixOS or
Home Manager module. Mechanics that matter:

- **The module's name is its filename**, via the standard header idiom
  (`lib.removeSuffix ".nix" (baseNameOf __curPos.file)`). Renaming a file
  therefore renames the module; if the category and file disagree after a
  rename, the file silently drops out of its category. `just modules`
  catches collisions and orphans.
- **Two modules with the same name merge** rather than conflict — the
  nastiest failure mode, which is why `just modules` exists as a static
  check and why the style guide demands a comment when a rename makes an
  old name ungreppable.
- `flake.modules` cannot live inside `perSystem` (no `<system>` axis, no
  `freeformType` there) — settled by reading upstream, recorded in
  `wiki/flake-parts-port-notes.md` and `flake/doc/flake-parts-rationale.md`.
- Classes seen in the tree: `nixos`, `homeManager`, `darwin`. One file can
  declare the same feature for two classes side by side (`nixd.nix` installs
  the LSP for both) instead of splitting one feature across two files.
- Class names are not validated at declaration; a wrong one fails at the
  import site.
- Paths containing `/_` are ignored by `import-tree` (that is how
  `_lib/`, `_disko/`, `_dashboards/`, `_templates/` opt out), and `!`-prefixed
  dirs (`!dotfiles/`) hold raw dotfiles with no `.nix` at all.
  `flake/scripts/host-fingerprint.nix` sits in `scripts/` rather than
  `modules/` for the same reason.

## Categories: membership is the directory

There are no `mkEnableOption`s anywhere. A feature is shared-and-optional by
being its own category directory, and a host opts in by importing the
category. The mechanism (`dirsAsCategory`):

- `_lib/category-collector.nix` holds the real logic (a plain Nix function,
  `import`ed by path; safe under `modules/` because of the `/_` rule). It
  was factored out of what were once ~38 byte-identical copies.
- Each category directory carries a two-line `dirsAsCategory.nix` shim that
  imports the collector and derives the category name from its own
  directory. 39 shims exist (20 in `nire/`, 14 in `nirePackages/`,
  4 in `nireHost/`, 1 in `nireUser/`);
  `nirePackages/_templates/dirsAsCategory.nix` is the copy-me template.
- **A category collects from its subdirectories only.** A `.nix` file placed
  directly in a category directory is collected by nothing.
- Adding a module is a one-file change; moving a file between directories
  moves it between categories; nothing else changes.
- Full mechanism + a conversion trailhead (deliberately not a
  recommendation): `flake/doc/dirsAsCategory.md`. The nested-catalog
  quirk of `nire/homelab/` (an umbrella category nesting cube-only
  sub-categories) is written up in `wiki/categories/homelab.md`.

Areas:

| Area | Role | Shape |
|---|---|---|
| `nire/` | Shared system config, all hosts | ~20 categories: `boot`, `desktop-env`, `hardware` (+`amd`, `amdgpu`), `homelab` (umbrella: `backup`, `containers`, `git-forge`, `landing`, `monitoring`, `reverse-proxy`, `shortlinks`, `virtualization`), `impermanence`, `macos`, `nix`, `peripherals`, `shell-config`, `system` (19 subcategories incl. `networking`, `home-manager`, `secrets`), … |
| `nireHost/` | Per-host | `hosts.nix` + four `<host>-configuration.nix` aggregates at top level (uncollected on purpose), then per-host `configuration/`, `hardware/`, `fixes/` subtrees |
| `nirePackages/` | Package groupings | Leaf convention `<tool>/<tool>.nix` (dir name = module filename); grouped `development/`, `editors/`, `gui-other/`, `linux-utils/`, `nix-utils/`, `shell-apps/`, `terminals/` |
| `nireUser/` | elly's Home Manager | `elly-home-manager.nix` aggregate at top level (uncollected), then the `elly/` category |

Entry points sit **outside every category tree** so nothing collects them:
`modules/checks.nix`, `modules/invariants.nix`, `nireHost/hosts.nix`, the
four `nireHost/*-configuration.nix`, and `nireUser/elly-home-manager.nix`.
`just modules` depends on exactly this.

One by-name variant exists: `kde-desktop` is imported directly by tenacity's
config while its category (`desktop-env`, which also holds `jovian`) is
never imported whole — the pattern for "most of a category, minus one".

The exception-to-everything file: `nire/impermanence/WARN-impermanence.nix`
is named `WARN-` because it wipes `/root` at boot; the prefix marks
deliberately loud guard modules (`WARN-password-required.nix` is the other).

## Host construction

`nireHost/hosts.nix` defines two builders and the flake outputs:

- `mkHost system hostModule` → `nixosSystem`, `mkDarwinHost` →
  `darwinSystem`. Both run inside `withSystem` so host modules receive
  `self'`/`inputs'` via `specialArgs`.
- Both **deliberately do not take `pkgs` from `perSystem`**: perSystem's
  `legacyPackages` has none of the host's `nixpkgs.config` applied, and
  silently dropping `allowUnfree` this way is the trap the comment at
  `hosts.nix:6-9` exists to prevent. `pkgs`/`config` belong to the inner
  module lambda; `lib`/`inputs` to the outer one.
- Outputs: `nixosConfigurations` = durandal, tenacity, cube;
  `darwinConfigurations` = lysithea. Removed hosts (`nire-lego`,
  `nire-installer`, the `nire-llm-sandbox` VM) are recorded in comments
  pointing at `wiki/history.md` and git history.

## Home Manager is NixOS-integrated (and darwin-shared)

- `nire/system/home-manager/enable-home-manager.nix` sets
  `home-manager.users.elly` **from the NixOS side** with `useGlobalPkgs`
  and `useUserPackages`. There is no `homeConfigurations` output and no
  separate home switch — `just switch` applies system + home in one
  activation.
- `ellyHomeManager` (in `nireUser/`) is shared verbatim by all four hosts
  including the darwin one, so everything in it must survive darwin:
  nixpkgs buildability is handled automatically by
  `nire/system/home-manager/drop-unsupported-packages.nix` (platform-gates
  off `meta.platforms`; never hand-restate with `mkIf (!isDarwin)`), but
  Homebrew overlap is **never** answered automatically — that is the
  `just available --duplicates` / skill `nirepackages-platform-support`
  discipline.
- Third-party HM modules are imported selectively: `plasma-manager`'s HM
  module is loaded only from tenacity's plasma config, never from
  `enable-home-manager.nix`.
- The escape hatch if integration is ever the wrong call:
  `flake/doc/trailhead-home-manager-standalone.md`.

## Checks and invariants

- `modules/checks.nix` forces each host's `system.build.toplevel` under
  `nix flake check`, so a broken host fails *evaluation* in CI rather than
  at 2 a.m. on the host. (CI still builds nothing — see
  [05](05-github-usage.md) and open issue #205.)
- `modules/invariants.nix` asserts things that must be *true* of an
  evaluated host, not merely resolvable — it `throw`s.

## Recommendations

- **R3 — the style guide's counts are snapshots and say so, but two are now
  wrong in a checkable way**: "The module header — 151 of 151 files" and
  "70 files" / "106 files" date from 2026-08-08 against a tree that is now
  263 files. The repo's own philosophy is "counts are checkable rather than
  asserted" — either re-derive them periodically or add a wiki-lint
  subcheck; otherwise the claims quietly invert (a reader concludes the
  header convention covers barely half the tree).
- No structural recommendation: the collector/shim/entry-point layout is
  internally consistent, mechanically checked (`just modules`), and its one
  historical scar (the 38-copy shim era) is already fixed and documented.
