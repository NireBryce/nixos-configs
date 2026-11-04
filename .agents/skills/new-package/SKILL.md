---
name: new-package
description: Adds a package to the user environment and verifies it on the target host.
when_to_use: Adding a package to the Home Manager package set, before writing the module.
---

# Adding a package in this repo

## Applies to

Use when adding `pkgs.<name>` (or a small handful) to `elly-home-manager` via `flake/modules/packages-config/`. Use it before writing the module: `just modules` and `just check` catch outright collisions, not a wrong category choice.

Other skills cover neighboring tasks:

- platform or Homebrew detail: `package-platform-support`
- a network service: `new-homelab-service`
- one module file's mechanics: `new-flake-module` (still applies)
- a whole host: `new-host-config`

The mechanism is the same on NixOS and darwin. Only the platform questions and the host that runs a real build differ (sections below).

## The shape

Write the module by hand and follow a sibling file:

```nix
# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: <tool> -- <what the package is, one line; nixpkgs meta.description is a start>
        home.packages = with pkgs; [
            <tool>
        ];
    };
}
```

`just add-module homeManager <path> "<description>"` writes the file with a `# summary:` line; in `packages-config/`, rename it to `# package summary:`. The `package summary:` line is required (`just wiki-lint`'s `summaries` check fails without it). Say what the package *is*, not just its name or a URL, so a reader browsing the module does not need to open nixpkgs.

Put the file at `packages-config/<category>/<tool>/<tool>.nix`. Some categories are flatter (`nix-utils/nvd/nvd.nix`, `terminals/kitty/kitty.nix`, `development/tools/ai-tools/herdr.nix`), so skim the target category first.

Wiring is automatic **once the category is already included**. The file is a member of the category above its folder (`wiki/config-structure/module-files.md`), and `users-config/elly-home-manager.nix` imports the coarse categories (`development`, `editors`, `gui-other`, `linux-utils`, `nix-utils`, `shell-apps`, `terminals`, plus non-package ones). A new category not listed there contributes nothing, so check that file.

## Category: by function, not tool family

The category is how the module is found later. `cmux` is a terminal whose description leans on "first-class support for AI coding agents"; it went in `development/tools/ai-tools/` beside `herdr.nix`, not in `terminals/` beside `kitty.nix`. If the category is not obvious, say why in the module comment, as `kitty.nix` and `obsidian.nix` do.

## The two platform questions

Before writing the module, run `just available <pkg>` and, for GUI apps, `just available --duplicates`. The mechanism and the `obsidian.nix`/`vicinae.nix` examples are in `package-platform-support`.

- **Does nixpkgs build it on darwin?** `drop-unsupported-packages.nix` answers this automatically (darwin only). Do not restate it with `lib.mkIf (!pkgs.stdenv.isDarwin)`.
- **Does Homebrew already install it?** This is never automatic. `--duplicates` finds the overlap; which copy wins is a judgment call.

**Darwin-only packages need a hand guard.** If a package's `meta.platforms` names only darwin (`cmux.nix`), wrap `home.packages` in `lib.mkIf pkgs.stdenv.hostPlatform.isDarwin`. Without it, every Linux host's `nix flake check` and toplevel build breaks when `buildEnv` forces the unbuildable derivation. This is the one legitimate hand-restated `meta.platforms` fact; read that skill's section first.

## Verify

Each step catches what the earlier ones cannot:

1. `git add -A`. Flakes ignore untracked files.
2. `just modules` reports untracked files, drift and orphans. A repeated name fails evaluation.
3. `just check` evaluates every host across `--all-systems`. It is the only step that catches a darwin-only package on Linux. `just agent preflight-brief` also runs modules, lint, script tests and `just wiki-lint`; a new `.nix` file moves the generated counts table in `wiki/config-structure/module-style-guide-for-agents.md`, so run `just wiki-gen` in the same change.
4. `just lint`.
5. **Run a real build, not just eval.** Run `just build` on the host itself. NixOS cannot be cross-built from another machine (no remote builder, no binfmt), and in practice the same holds for darwin outside `nire-lysithea`. Otherwise sync and build over ssh as `new-homelab-service` step 5 does for `nire-cube`. Read `nh`'s diff (`ADDED`/`PATHS`/`SIZE`) and confirm the new package is the only thing that moved.
6. `just switch` needs interactive `sudo`, so the user runs it. Hand it over once the diff looks right.

## Ship

Use the `ship` skill: branch, PR, one combined ask covering the merge and deleting the branch.

## See also

- `package-platform-support`: platform/Homebrew decision, darwin-only case.
- `new-flake-module`: the module shape, filenames, classes, collisions.
- `wiki/config-structure/module-style-guide.md`: formatting (aligned `=`, no `nix fmt`).
