# Why flake-parts, and what of it is actually used

> **Written by Claude Code.** A working note, not documentation — same
> footing as `dirsAsCategory.md`: checked by reading the actual imports and
> grepping for actual usage, not by reasoning about what flake-parts
> generally offers.

## The rationale

The reason this repo runs flake-parts, ahead of everything listed under
"What's actually used" below, is one option:
`flake-parts.flakeModules.modules` (imported at
[`../flake.nix:10`](<../flake.nix#L10>)), which declares
`flake.modules.<class>.<name>` as a `deferredModule`. Many files can write
into the same `<class>.<name>` slot and the module system merges them —
and one file can write into *several classes* at once, as sibling
attributes of the same attrset. That's the payoff: a single `.nix` file
can hold both a NixOS module and a Home Manager module for the same
feature, instead of a NixOS-side file and a Home-Manager-side file tied
together by nothing but a shared filename.
`flake/modules/nirePackages/nix-utils/nixd/nixd.nix` in full:

```nix
{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
        home.packages = with pkgs; [ nixd ];
    };

    flake.modules.nixos.${moduleName} = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [ nixd ];
    };
}
```

Everything else — `dirsAsCategory` deriving category membership from
directory placement, hosts assembling config from
`config.flake.modules.<class>.<name>` (`hosts.nix`) — is built on top of
that one option. Without it, NixOS and Home Manager halves of a feature
would need separate files with no mechanism tying them together.

## What's actually used

- **`darwin.flakeModules.default`** (`../flake.nix:16`) — nix-darwin's own
  module, declaring `flake.darwinConfigurations`. Not strictly required
  (`freeformType` on `flake` would accept it same as
  `flake.nixosConfigurations`), just no reason to hand-roll it.
- **`flakeModules.touchup`** (`../flake.nix:38`) — one line,
  `touchup.attr.formatter.enable = false`, dropping the `formatter` output
  entirely. See `../flake.nix:18-37` for why: flake-parts can't statically
  prove no `perSystem.formatter` is set for every system, and CI failed on
  exactly that before this line existed.
- **`systems`** (`../flake.nix:40-43`, `["x86_64-linux" "aarch64-darwin"]`)
  — drives `perSystem` iteration.
- **`perSystem`** — two files, both only `perSystem.checks`, both taking
  just `{ system, pkgs, ... }`:
  - `modules/checks.nix` forces every host's `system.build.toplevel` (and
    the Home Manager `activationPackage`, where a host has one) as a named
    check, filtered to hosts matching that system. Its own header explains
    why: evaluating a cheap attribute like `networking.hostName` missed
    several real breakages, forcing the toplevel is what caught them.
  - `modules/invariants.nix` — same shape, for host-topology invariants
    instead of build forcing.

  Neither uses `inputs'`/`self'`. The `checks.<system>.*` flake output
  comes from flake-parts' own perSystem→flake merge — nothing else here
  does that.
- **`withSystem`** — one call site, `modules/nireHost/hosts.nix`, to get
  `self'`/`inputs'` for `specialArgs`. Deliberately **not** used for
  `pkgs`: `nixosSystem`/`darwinSystem` build their own `pkgs` from the
  host's own `nixpkgs.config`, and `perSystem`'s default
  `legacyPackages.<system>` has none of that — taking `pkgs` from there
  would silently drop `allowUnfree`. See `hosts.nix:3-9`.

## What's not used

Checked by grep — none of these appear anywhere in `flake/`:

- **`moduleWithSystem`** — `hosts.nix` uses `withSystem` directly instead
  (it's a module argument there, not called from outside one).
- **`debug`** — the `mkFlake` debug option is never set.
- **Any other bundled `flakeModules`** — `easyOverlay`, `partitions`, etc.
  are never imported.
- **`perSystem.packages` / `.devShells` / `.apps` / `.overlays`** — no dev
  shell, custom package, or app output goes through flake-parts here.
  `.formatter` is the one flake-parts would otherwise require something
  for — that's what `touchup` is for, above.
- **Overlay/`legacyPackages` composition** — the two `legacyPackages` hits
  in this tree (a comment in `jovian.nix`, a comment in `hosts.nix`) are
  about avoiding it, not using it.

## See also

- `../doc/dirsAsCategory.md` — the mechanism built on
  `flake.modules.<class>.<name>`, in full.
- `../doc/trailhead-home-manager-standalone.md` — the other half of "NixOS
  and Home Manager in the same file": how Home Manager is wired in from
  the NixOS side rather than as a standalone flake output.
- `../../CLAUDE.md`, Architecture section — the prose overview this note
  fills the "why" and "what's unused" gaps of.
- `../../wiki/architecture.md` — the wiki's index into this page.
