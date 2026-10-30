# Adding a package

Adding a package to the user environment is a one-file change that every
host picks up through Home Manager. This page covers where the file goes,
what it contains, when it needs a platform guard, and how to verify it. Two
different platform questions produce guards that look identical in config;
Step 2 separates them.

## Before you start: the shared package set

Packages live under `flake/modules/packages-config/`, one file per package.
They reach every host through one [Home Manager](glossary.md#home-manager)
module, `elly-home-manager`, which every host shares unchanged, **including
any darwin host** (see `host-config/hosts.nix`). Every package you add must
therefore survive aarch64-darwin as well as Linux.

`elly-home-manager` includes the package [categories](glossary.md#category)
`development`, `editors`, `gui-other`, `linux-utils`, `nix-utils`,
`shell-apps` and `terminals` by name. A file under one of those folders is
wired in automatically. A new top-level package category that
`elly-home-manager.nix` doesn't list contributes nothing.

## Step 1: pick the category by function

Choose the folder by what the tool is for, so the module can be found later,
and ignore which family the tool belongs to. `cmux` is a terminal, but its
description leans on support for AI coding agents, so it went in
`development/tools/ai-tools/` beside `herdr.nix`, not in `terminals/` beside
`kitty.nix`. If the choice isn't obvious, explain it in the module's header
comment.

The usual path is `packages-config/<category>/<tool>/<tool>.nix`. Some
folders are flatter, for example `development/tools/ai-tools/herdr.nix` and
`shell-apps/text-tools/ripgrep.nix`. List the target folder and follow the
layout already there.

## Step 2: answer the two platform questions

Run these commands **before** writing the module:

```sh
just available <pkg>            # can it build on the system? (defaults to aarch64-darwin)
just available --duplicates     # which Home Manager packages a Homebrew cask ALSO installs
```

### Can nixpkgs build it on darwin? The repo handles this

`general-config/system/home-manager/drop-unsupported-packages.nix` re-declares
`home.packages` with an `apply` function that filters by
`lib.meta.availableOn` on darwin only, and warns by name about each package
it drops. **Do not** add `lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin)` to a
package module for platform reasons: `meta.platforms` already records the
platforms, and a hand-written copy can drift.

On Linux the filter does nothing, so a package that can't build on the NixOS
hosts stays an error.

The filter has three limits:

- It reaches only `home.packages`. A module that sets other options, such as
  `programs.foo.enable` or `services.foo.enable`, asserts before any package
  list exists. It needs its own `lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin)`
  guard. `vicinae.nix`, `kde-connect.nix` and `kde-sleepmode.nix` are
  examples.
- It does not catch `meta.broken`. `cod` is broken on darwin, so the zsh and
  bash modules that use it guard it by hand.
- It cannot be replaced by making `imports` conditional on `pkgs`. Under
  [`useGlobalPkgs`](glossary.md#useglobalpkgs-and-useuserpackages) a
  conditional `imports` causes infinite recursion (confirmed on the Linux
  hosts), so filtering has to happen on values.

### Does Homebrew already install it? You decide

`meta.platforms` knows nothing about Homebrew. When a cask in
`general-config/macos/homebrew/homebrew.nix` overlaps a nixpkgs package, the
darwin host gets two copies. Which copy wins is a judgment per app, and
`just available --duplicates` lists the overlaps.

### Worked example of the Homebrew guard: `obsidian.nix`

`packages-config/gui-other/pkm/notes/obsidian.nix` wraps its package list
like this:

```nix
{
    homeManager = { pkgs, lib, ... }:
        # Excluded on darwin because general-config/macos/homebrew/homebrew.nix already
        # installs the `obsidian` cask, so lysithea was getting two copies.
        lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
        home.packages = with pkgs; [
            obsidian
        ];
        # … a .desktop alias for KWin, Linux-side …
    };
}
```

The guard reads as "Linux-only" but means "on darwin, `homebrew.nix` owns
this app". Obsidian builds on aarch64-darwin; the nix copy was dropped
because it is an unfree repackaged `.dmg` that is never in the binary cache,
and a failed download broke the whole darwin build. Before copying an
`isDarwin` test from another module, work out which of the two questions it
answers.

### The opposite case: a darwin-only package

A package whose `meta.platforms` names **only** darwin needs the opposite
guard. On Linux the filter is the identity function, so an unguarded package
stays in `home.packages`, and `nix flake check` or the toplevel build fails
on every Linux host with `Refusing to evaluate package … because it is not
available on the requested hostPlatform`. `cmux.nix` is the example:

```nix
{
    homeManager = { pkgs, lib, ... }:
        lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
            # cmux: macOS-native terminal built on Ghostty for AI coding agents
            home.packages = with pkgs; [
                cmux
            ];
    };
}
```

A darwin-only package is the one case where restating `meta.platforms` by
hand is correct.

## Step 3: write the module

Copy a sibling file. The ordinary case has no guard at all:

```nix
# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: <tool> -- what the package is, in one line
        home.packages = with pkgs; [
            <tool>
        ];
    };
}
```

The `homeManager` key is the file's [module class](glossary.md#module-class).
Rules:

- The filename is the module name. It must not match any existing module or
  category name anywhere in the tree, or evaluation stops.
- Put `pkgs` in the inner `homeManager` lambda, never in the outer header.
  A `pkgs` from anywhere else comes from
  [perSystem](glossary.md#persystem), a different instance from the host's.
- Write one `# package summary:` line that says what the package is. The
  name alone is not enough.
- Use `with pkgs; [ … ]`, one package per line, with no `pkgs.` prefix inside
  the list.

`just add-module homeManager packages-config/<category>/<tool>/<tool>.nix "<description>"`
writes the file, runs `git add` and runs the checks. Afterwards:

- Change `# summary:` to `# package summary:`.
- Change the inner lambda `_:` to `{ pkgs, ... }:`.
- Add the `home.packages` body.

## Step 4: verify, one rung at a time

Run the checks in order. Each catches something the earlier ones cannot:

```sh
git add -A          # flakes ignore untracked files: an unstaged module does not exist
just modules        # untracked files; drift between wiki-lint's reading and the graph
just check          # evaluates every host on every system: the only step that
                    # catches a darwin-only package breaking the Linux hosts
just lint           # statix + deadnix, ratcheted against a baseline
just build          # a real build, on the host itself
```

- `just preflight` runs what CI runs. A new `.nix` file changes the
  generated counts table in
  `wiki/config-structure/module-style-guide-for-agents.md`, so run
  `just wiki-gen` in the same change.
- A NixOS host can't be built from another machine (no remote builder, no
  binfmt), so run `just build` on the target. Read `nh`'s diff and confirm
  the new package is the **only** change.
- `just switch` needs interactive `sudo`, so the user runs it.

Report the highest level you reached: *evaluates* (`just check`), *builds*
(`just build`), or *runs* (switched and used).

## Where to go next

- How module files work in general: [Adding a module](adding-a-module.md).
- Why a new folder can change category membership: [Categories and
  membership](categories.md).
- The darwin side of the shared home config: [Darwin edge cases](darwin.md).

## Sources

- `.agents/skills/new-package/SKILL.md`
- `.agents/skills/package-platform-support/SKILL.md`
- `.agents/rules/packages.md`
- `AGENTS.md`, "Before calling it done"
- `flake/modules/users-config/elly-home-manager.nix`
- `flake/modules/general-config/system/home-manager/drop-unsupported-packages.nix`
- `flake/modules/packages-config/gui-other/pkm/notes/obsidian.nix`
- `flake/modules/packages-config/development/tools/ai-tools/cmux.nix`
- `flake/scripts/modules.py` (`BOILERPLATE`, `add`)
- [module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md)
