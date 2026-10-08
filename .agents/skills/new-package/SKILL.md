---
name: new-package
description: How to add a package to a user's environment in this repo and verify it on the target host.
---

# Adding a package in this repo

## Applies to

Adding `pkgs.<name>` (or a small handful) to `ellyHomeManager` via
`flake/modules/packages-config/`. Use before writing the module — `just
modules`/`just check` catch outright collisions, not a wrong category
choice.

Not this skill: platform/Homebrew detail → `package-platform-support`; a
network service → `new-homelab-service`; one module file's mechanics →
`new-flake-module` (still applies); a whole host → `new-host-config`.

Same mechanism on NixOS and darwin; only the platform questions and the
host a real build runs on differ (sections below).

## The shape

Hand-written, not generated. Follow a sibling file:

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

File at `packages-config/<category>/<tool>/<tool>.nix` (some flatter:
`nix-utils/nixfmt/nixfmt.nix`, `terminals/kitty/kitty.nix`,
`development/tools/ai-tools/herdr.nix`; skim the target category first).

Wiring is automatic **once the category is already imported**: `dirsAsCategory`
makes the file a member of its directory's category, and
`users-config/elly-home-manager.nix` imports the coarse categories
(`development`, `editors`, `gui-other`, `linux-utils`, `nix-utils`,
`shell-apps`, `terminals`, plus non-package ones). A new category not listed
there contributes nothing — check that file.

## Category: by function, not tool family

It's how the module is found later. `cmux` (terminal whose description leans
on "first-class support for AI coding agents") went in
`development/tools/ai-tools/` beside `herdr.nix`, not `terminals/` beside
`kitty.nix`. If not obvious, say why in the module comment, as `kitty.nix`
and `obsidian.nix` do.

## The two platform questions

Run `just available <pkg>` and, for GUI apps, `just available --duplicates`
**before** writing the module (mechanism, `obsidian.nix`/`vicinae.nix`
examples: `package-platform-support`).

- **nixpkgs builds it on darwin?** Automatic via
  `drop-unsupported-packages.nix` (darwin only). Don't hand-restate with
  `lib.mkIf (!pkgs.stdenv.isDarwin)`.
- **Homebrew already installs it?** Never automatic; `--duplicates` finds
  the overlap; which wins is a judgement call.

**Mirror case needing a hand guard**: a package whose `meta.platforms` names
only darwin (`cmux.nix`) needs `lib.mkIf pkgs.stdenv.isDarwin` around
`home.packages`, or every Linux host's `nix flake check`/toplevel build
breaks when `buildEnv` forces the unbuildable derivation. The one legitimate
hand-restated `meta.platforms` fact; read that skill's section first.

## Verify

Each step catches what earlier ones can't:

1. `git add -A` — flakes ignore untracked files.
2. `just modules` — name collisions, orphans.
3. `just check` (or `just preflight`: also modules, lint, script tests,
   `just wiki-lint` -- a new `.nix` file moves the generated counts table in
   `wiki/module-style-guide-for-agents.md`; `just wiki-gen` in the same change) —
   evaluates every host across `--all-systems`; the only step that catches
   the darwin-only-package-on-Linux mistake.
4. `just lint`.
5. **A real build**, not just eval: `just build` on the host itself (NixOS
   can't be cross-built from another machine — no remote builder, no
   binfmt; in practice same for darwin outside `nire-lysithea`); otherwise
   sync and build over ssh as `new-homelab-service` step 5 does for
   `nire-cube`. Read `nh`'s diff (`ADDED`/`PATHS`/`SIZE`); confirm the new
   package is the *only* thing that moved.
6. `just switch` is the human's (needs interactive `sudo`); hand it over
   once the diff looks right.

## Ship

`ship` skill: branch, PR, ask before merging, ask again before deleting the
branch.

## See also

- `package-platform-support` — platform/Homebrew decision, darwin-only case.
- `new-flake-module` — filenames, classes, two `config`s, collisions.
- `wiki/module-style-guide.md` — formatting (aligned `=`, no `nix fmt`).
