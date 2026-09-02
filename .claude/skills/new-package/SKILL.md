---
name: new-package
description: How to add a package to a user's environment in this repo and verify it on the target host.
---

# Adding a package in this repo

## Applies to

Adding `pkgs.<name>` (or a small handful) to `ellyHomeManager` via
`flake/modules/nirePackages/`. Use before writing the module — `just
modules`/`just check` catch outright collisions, not a wrong category
choice.

Not this skill: platform support and Homebrew overlap in detail →
`nirepackages-platform-support`; a network service → `new-homelab-service`;
one module file's mechanics → `new-flake-module` (those rules still apply
here); a whole host → `new-host-config`.

The mechanism is identical on NixOS and darwin; only the platform questions
and which host a real build runs on differ — one section each below, not a
second skill.

## The shape

Hand-written, not generated. `nirePackages/_lib/mkPkgModule.nix` exists as a
generator for this exact shape (~70 files already match it, per
`flake/scripts/mkPkgModule.md`) but is a **deliberately unused draft** —
nothing in the tree calls it. Don't reach for it; follow a sibling file
instead.

```nix
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
                # <tool>: <one-line description, e.g. from nixpkgs meta.description>
                home.packages = with pkgs; [
                    <tool>
                ];
        };
}
```

File it at `nirePackages/<category>/<tool>/<tool>.nix` (some categories are
flatter — `nix-utils/nixfmt/nixfmt.nix`, `terminals/kitty/kitty.nix`,
`development/tools/ai-tools/herdr.nix` are all real, current examples; skim
a few in the target category before picking the exact depth).

Wiring is automatic **once the category is already imported**:
`dirsAsCategory` makes the new file a member of whatever category directory
it's filed under, and `nireUser/elly-home-manager.nix` already imports the
coarse categories that exist today (`development`, `editors`, `gui-other`,
`linux-utils`, `nix-utils`, `shell-apps`, `terminals`, plus the non-package
ones). Check that file before assuming a new category reaches anywhere — an
aggregate that isn't listed there contributes nothing no matter how correct
the module is.

## Pick the category by function, not by tool family

The category is how the module gets found later, so it's a real decision,
not a formality. `cmux` — a terminal, but one whose own description leans on
"first-class support for AI coding agents" — went in
`development/tools/ai-tools/` next to `herdr.nix` ("agent multiplexer that
lives in your terminal"), not `terminals/` next to `kitty.nix` (a plain
terminal emulator). When the choice isn't obvious, say why in the module's
own comment, the way `kitty.nix` and `obsidian.nix` explain their split and
their guard.

## The two platform questions

Run `just available <pkg>` and, if it's a GUI app, `just available
--duplicates` **before** writing the module — full mechanism, and the
`obsidian.nix`/`vicinae.nix` worked examples, are in skill
`nirepackages-platform-support`. Short version:

- **Can nixpkgs build it on darwin?** Answered automatically by
  `drop-unsupported-packages.nix`, darwin only. Don't hand-restate with
  `lib.mkIf (!pkgs.stdenv.isDarwin)`.
- **Does Homebrew already install it?** Never automatic. `just available
  --duplicates` finds the overlap; which one wins is a judgement call.

**The one case that skill flags as needing a hand guard in the *other*
direction**: a package whose `meta.platforms` names only a darwin system
(`cmux.nix` is the worked example) needs `lib.mkIf pkgs.stdenv.isDarwin`
around its `home.packages`, or every Linux host's `nix flake check` and
toplevel build breaks the moment `buildEnv` forces the unbuildable
derivation. This is the one legitimate case in the tree for restating a
`meta.platforms` fact by hand — see that skill's own section on it before
copying the shape.

## Verify

Each step catches something the ones before it can't:

1. `git add -A` first — flakes ignore untracked files, so a new module
   silently doesn't exist yet.
2. `just modules` — category/module name collisions and orphans.
3. `just check` (or `just preflight`, which bundles this with the next two)
   — evaluates every host across `--all-systems`. This is what actually
   catches the darwin-only-package-on-Linux mistake above; a narrower check
   against just the target host would miss it.
4. `just lint`.
5. **A real build**, not just eval. `just build` from the host itself if
   you're on it (a NixOS host can't be cross-built from another machine —
   no remote builder, no binfmt — and in practice the same is true of
   darwin outside a session actually running on `nire-lysithea`); otherwise
   sync and build over ssh the way `new-homelab-service` step 5 does for
   `nire-cube`. Read the diff `nh` prints (`ADDED`/`PATHS`/`SIZE`) rather
   than trusting a changed drvPath alone — confirm the new package is the
   *only* thing that moved.
6. `just switch` is the human's: it needs the machine's own interactive
   `sudo` password, so an agent session can build and verify but not
   activate. Hand it over once the build's diff looks right.

## Ship

`ship` skill: branch, PR, ask before merging, ask again before deleting the
branch.

## See also

- `nirepackages-platform-support` — the platform/Homebrew decision in full,
  including the darwin-only mirror case this skill only summarizes.
- `flake/scripts/mkPkgModule.md` — why the generator exists and why nothing
  converts to it yet.
- `new-flake-module` — filenames, classes, the two `config`s, category
  collisions.
- `wiki/module-style-guide.md` — formatting (aligned `=` columns,
  `nix fmt` deliberately not wired up).
