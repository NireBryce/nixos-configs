# Adding a package

Adding a package to the user environment is a one-file change that every
host picks up through Home Manager. The steps below cover where the file
goes, what it contains, when it needs a platform guard, and how to verify
it. Two different platform questions produce guards that look identical in
config, so step 2 separates them. Unfamiliar terms are in the
[glossary](glossary.md).

## Before you start: the shared package set

Packages live under `flake/modules/packages-config/`, one file per package.
They reach every host through one [Home Manager](glossary.md#home-manager)
module, `elly-home-manager`. Every host shares that module unchanged,
**including any darwin host** (see `host-config/hosts.nix`). Every package
you add therefore has to survive aarch64-darwin as well as Linux.

`elly-home-manager` includes the coarse package
[categories](glossary.md#category) by name: `development`, `editors`,
`gui-other`, `linux-utils`, `nix-utils`, `shell-apps`, `terminals`. (A
category is a folder whose modules a host or aggregate takes by one name.) A
file under one of those folders is wired in automatically. A new top-level
package category that `elly-home-manager.nix` doesn't list contributes
nothing.

Source: `.agents/skills/new-package/SKILL.md`, "The shape";
`flake/modules/users-config/elly-home-manager.nix`.

## Step 1: pick the category by function

Choose the folder by what the tool is *for*, so that the module can be
found later. Ignore which family the tool belongs to. The recorded example:
`cmux` is a terminal, but its description leans on support for AI coding
agents. It went in `development/tools/ai-tools/` beside `herdr.nix`; it did
not go in `terminals/` beside `kitty.nix`. If the choice isn't obvious, explain it in
the module's header comment.

The usual path is `packages-config/<category>/<tool>/<tool>.nix`. Some
folders are flatter, for example `development/tools/ai-tools/herdr.nix` and
`shell-apps/text-tools/ripgrep.nix`.

Check: list the target folder and follow the layout already there.

Source: `.agents/skills/new-package/SKILL.md`, "Category: by function, not
tool family".

## Step 2: answer the two platform questions

Run these commands **before** writing the module:

```sh
just available <pkg>            # can it build on the system? (defaults to aarch64-darwin)
just available --duplicates     # which Home Manager packages a Homebrew cask ALSO installs
```

The two commands answer different questions, and the repo handles only one
of them automatically.

### Can nixpkgs build it on darwin? The repo handles this

`general-config/system/home-manager/drop-unsupported-packages.nix` filters
`home.packages` by `meta.platforms` on darwin and warns by name about each
package it drops. **Do not** add `lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin)`
to a package module for platform reasons. `meta.platforms` already records
the platforms, and a hand-written copy can drift. The filter has two gaps:

- It reaches only `home.packages`. A module whose body is
  `programs.foo.enable` or `services.foo.enable` asserts before any package
  list exists, and needs its own guard. `vicinae.nix` is the example.
- It does not catch `meta.broken`. `cod` is the live example, and the
  modules that use `cod` still guard it by hand.

On Linux the filter does nothing, by design: a package that can't build on
the NixOS hosts should stay a loud error.

### Does Homebrew already install it? You decide

`meta.platforms` knows nothing about Homebrew. The casks in
`general-config/macos/homebrew/homebrew.nix` can overlap with nixpkgs
packages, and then the darwin host gets two copies. Deciding which copy wins
is a judgment per app.

Check: `just available --duplicates` lists the packages that both sides
install.

Source: `.agents/skills/package-platform-support/SKILL.md`;
`.agents/rules/packages.md`; header of `drop-unsupported-packages.nix`.

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

The guard in `obsidian.nix` reads as "Linux-only", but it means *"on darwin,
`homebrew.nix` owns this app"*. Obsidian builds fine on aarch64-darwin. The
nix copy was dropped because it is the expensive one: an unfree repackaged
`.dmg` that is never in the binary cache. Once, the GitHub download of that
`.dmg` returned 503 on every retry. The whole darwin build failed, for an app
Homebrew had already installed.

Before you copy an `isDarwin` test from another module, read it and work out
which of the two questions it answers.

Source: `flake/modules/packages-config/gui-other/pkm/notes/obsidian.nix`;
`.agents/skills/package-platform-support/SKILL.md`, "Does Homebrew already
install it?".

### The opposite case: a darwin-only package

A package whose `meta.platforms` names **only** darwin needs the opposite
guard. On Linux the filter is the identity function, so an unguarded
darwin-only package stays in `home.packages`. `nix flake check` or the
toplevel build then fails on every Linux host with `Refusing to evaluate
package … because it is not available on the requested hostPlatform`.
`cmux.nix` is the example:

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

Source: `flake/modules/packages-config/development/tools/ai-tools/cmux.nix`;
`.agents/skills/package-platform-support/SKILL.md`, "Darwin-only package".

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

The `homeManager` key is the file's [module class](glossary.md#module-class):
the kind of configuration the module targets. Get these points right:

- The filename is the module name. It must not match any existing module or
  category name anywhere in the tree, or evaluation stops.
- Put `pkgs` in the inner `homeManager` lambda, never in the outer header.
  A `pkgs` from anywhere else comes from
  [perSystem](glossary.md#persystem) and loses `allowUnfree`.
- Write one `# package summary:` line that says what the package *is*.
  The name alone is not enough.
- Use `with pkgs; [ … ]`, one package per line, with no `pkgs.` prefix inside
  the list.

`just add-module homeManager packages-config/<category>/<tool>/<tool>.nix "<description>"`
can write the file for you. It also runs `git add` and the checks. The
scaffolder leaves three edits to you:

- It writes `# summary:`; change it to `# package summary:` in this area.
- It writes `_:` as the inner lambda; change it to `{ pkgs, ... }:` before
  you use `pkgs`.
- It writes no `home.packages` list; add the body.

Check: `just add-module` refuses a name that a module or category already
uses. For a file written by hand, the same collision stops evaluation in
step 4.

Source: `.agents/skills/new-package/SKILL.md`, "The shape";
`flake/scripts/modules.py` (`BOILERPLATE`, `add`);
[module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md).

## Step 4: verify, one rung at a time

Run the checks in order. Each one catches something the earlier ones can't:

```sh
git add -A          # flakes ignore untracked files: an unstaged module does not exist
just modules        # untracked files; drift between wiki-lint's reading and the graph
just check          # evaluates every host on every system: the only step that
                    # catches a darwin-only package breaking the Linux hosts
just lint           # statix + deadnix, ratcheted against a baseline
just build          # a real build, on the host itself
```

- `just preflight` runs what CI runs. Adding a new `.nix` file changes the
  generated counts table in
  `wiki/config-structure/module-style-guide-for-agents.md`, so run
  `just wiki-gen` in the same change.
- A NixOS host can't be built from another machine (there is no remote
  builder and no binfmt). Run `just build` on the target. Read `nh`'s diff
  and check that the new package is the **only** thing that changed.
- `just switch` needs interactive `sudo`, so switching is nire's step.

When you report the result, name the rung you reached: *evaluates*,
*builds*, or *runs*.

Source: `.agents/skills/new-package/SKILL.md`, "Verify"; `AGENTS.md`,
"Before calling it done".

## Where to go next

- How module files work in general: [Adding a module](adding-a-module.md).
- Why a new folder can change category membership: [Categories and
  membership](categories.md).
- The darwin side of the shared home config: [Darwin edge cases](darwin.md).
