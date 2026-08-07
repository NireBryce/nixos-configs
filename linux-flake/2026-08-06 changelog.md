# 2026-08-06 changelog — flake-parts cleanup

Went through the flake against the flake-parts docs and fixed what was found.
11 commits on `flake-parts`, from `922289e` to `e0278d2`. `nix flake check
--all-systems` passes now; it didn't before, and neither host evaluated.

## What was actually broken

The flake did not evaluate at all when this started.

1. `modules/hosts/tenacity/hardware-configuration.nix` was raw
   `nixos-generate-config` output sitting in the `import-tree ./modules` path.
   import-tree handed it to flake-parts, which tried to resolve its
   `modulesPath` arg through flake-parts' own `_module.args` → infinite
   recursion. `self.modules.nixos.tenacityHardware` was referenced by tenacity
   but never declared. (fixed in `922289e`)

2. `flake.modules.jovian.wm-jovian` — there is no `jovian` module class.
   flake-parts stamps the outer attr name onto the module as `_class` verbatim
   and does *no* validation, so this produced a class-`"jovian"` module that
   `nixosSystem` refused to import. Real classes: `nixos`, `flake`, `generic`
   (+ `homeManager`/`darwin`, which work only because HM and nix-darwin set
   those `_class` values themselves). (`5added8`)

3. Then, once `nix flake check` started forcing tenacity's toplevel, two more
   fell out — both pre-existing, both hidden because nothing had ever
   evaluated past `networking.hostName`. **Tenacity could not have built.**
   (`5d69848`)
   - `adjustor` was removed from nixpkgs, folded into `handheld-daemon`. The
     `services.handheld-daemon.adjustor` option already pulls it in.
   - `LD_LIBRARY_PATH` read `inputs.jovian.decky-loader.extraPackages`, but the
     Jovian flake exposes no `decky-loader` attr at all. Wanted the module
     option: `config.jovian.decky-loader.extraPackages`.

Point 3 is the whole argument for having checks. Add them first next time.

## What changed

- `d93fb52` — `perSystem.checks` forcing every host's `system.build.toplevel`,
  filtered to the current system so `nix flake check` on the mac skips the
  linux hosts. `perSystem` was previously unused entirely.
- `d5b72d8` — `nix fmt` via treefmt-nix. **Configured but not run**, and
  `flakeCheck = false`. Running nixfmt reformats every file and flattens the
  aligned-`=` style. `just fmt` when you want it; flip `flakeCheck` in the same
  commit as the reformat.
- `319d67b` — **the big one.** durandal and tenacity each hand-maintained ~25
  module names overlapping in ~19. Now `base` / `desktop` / `handheld`, with
  each module opting *itself* in next to its own definition. Adding a module is
  a one-file change. See `modules/roles.nix`.
- `e180eb0` — `nixosConfigurations` through `withSystem`, so hosts get `self'` /
  `inputs'` via specialArgs. Deliberately still lets `nixosSystem` build its
  own pkgs; perSystem's default `legacyPackages` has no `allowUnfree`.
- `97b38bf` — same opt-in treatment for homeManager, killing the
  `removeAttrs self.modules.homeManager [ "ellyHomeManager" ]` aggregator and
  its TODO.
- `cd520dc` — Home Manager now managed from NixOS. It was wired both ways but
  the integrated side never set `home-manager.users.*`, so it was inert and
  only durandal had a standalone config — **tenacity had no home config at
  all.** One `nixos-rebuild` now does both.
- `e62d0cf` — empty `description`; dropped the `pipe-operators` nixConfig (no
  `|>` anywhere in the repo, cost a trust prompt per machine); dropped the
  unused `darwin` input.
- `7dd07cf` — `.justfile` had zero recipes, only comments, one pointing at a
  `nire-tenacity-hm-elly` config that never existed. `update-flake.sh` ended
  mid-line on `./scripts/flake-file/flake-file-`.
- `e0278d2` — zsh `initExtraFirst`/`initExtraBeforeCompInit`/`initExtra` →
  one `initContent` mkMerge (`mkBefore` / `mkOrder 550` / unordered), which the
  file's own TODO block had already spelled out. `xorg.xwininfo` → `xwininfo`.

- `72a2bf7` — `pkgs-hm/` (104 raw HM modules behind a nested `import-tree`,
  outside the flake-parts tree entirely) → `modules/pkgs/{cli,gui,linux-utils}`,
  each file its own flake-parts module opting into its group. Byte-identical
  output. 119 addressable homeManager modules, up from 15.

## How it was verified

Every refactor was diffed attribute-by-attribute against its predecessor, not
just "does it still evaluate":

- role refactor: identical systemd services, users, fileSystems,
  `environment.etc`, fonts, kernel modules, and an identical *set* of
  systemPackages (376 durandal / 330 tenacity). Only the **order** of
  systemPackages changed, because module import order changed — so the toplevel
  drvPath differs. Sets equal; only buildEnv collision tie-breaks could shift.
- homeManager aggregate: byte-identical drvPath
  (`1lcbk5m47ncliz4b05lhnldnfcydg3v1-home-manager-generation.drv`).
- `withSystem`, flake.nix hygiene, zsh migration, xwininfo: byte-identical.
- zsh migration specifically: generated `~/.zshrc` identical at 105572 bytes.
  Only option/delimiter lines were moved, `''` bodies untouched, so indentation
  stripping is unaffected.

## Gotchas worth remembering

- **Untracked files are invisible to flakes in a git repo.** Spent a confused
  minute on `checks` evaluating to `[ ]` because `modules/checks.nix` wasn't
  `git add`ed yet. `git add` before `nix eval`.
- `flake.modules.<class>.<name>` is a `deferredModule`, so **several files can
  define the same aggregate and they merge**. That's the whole mechanism behind
  the roles refactor. `nix` and `dev-tools` were already relying on it
  accidentally, split across 3 and 2 files.
- Prefer `config.flake.modules.…` over `self.modules.…` inside flake modules —
  same data without the round trip through flake outputs.
- flake-parts does not validate module class names. A typo there gets you a
  confusing error at *import* time, far from the declaration.

## Left alone, on purpose

- **Two evaluation warnings remain**, both from `home.stateVersion = "22.11"`
  leaving `programs.git.signing.format` and `programs.swaylock.enable` on
  legacy defaults. Not deprecations — silencing them means deciding whether to
  adopt the new defaults, which changes behaviour.
- `useGlobalPkgs = true` forced dropping `elly-nix-settings`' `nixpkgs.config`
  (HM rejects those options in that mode). `allowUnfree` is still set
  system-wide, but **the `allowUnfreePredicate` workaround for HM issue #2942
  is gone.** If that bug resurfaces, that's why.
- `macos/` is still a separate flake with divergent inputs (it pins
  `nixpkgs-unstable`, this pins `nixos-unstable`). `aarch64-darwin` is already
  in `systems`, so folding it in is the natural end state.
- `hosts/durandal/system-base-packages.nix` is in `base` — both hosts use it —
  despite living under `hosts/durandal/`. Misleading path, but moving it is
  pure churn since import-tree ignores location.
- `impermanence-WARN-README` belongs to no role; it was commented out of
  durandal's list and that comment was carried over.
