---
paths:
  - "flake/modules/**"
  - "flake/flake.nix"
---

# Writing, renaming, or browsing flake-parts modules

Full mechanism and worked examples: skill `new-flake-module`.

## Module shape

`wiki/config-structure/module-files.md` is the why; dirs-as-categories' `doc/convention.md`
the full rules.

- A module file is `{ nixos = …; homeManager = …; darwin = …; }`, or a
  function of only `lib`/`inputs` returning that. Its name is its filename
  (`default.nix`: its folder's); nothing in the file names it. Its header
  is a dirs-as-categories comment saying so (`wiki/config-structure/module-files.md`).
- `pkgs` and `config` belong in the inner (class) module's arguments; a
  module file cannot take the flake-parts `config` at all. The flake's own
  outputs are `inputs.self` (`tailnet-hosts.nix`).
- A rename renames the module. Two modules with one name, or a module named
  like a category, stop evaluation naming both files (§34, §35).
- A mistyped class key beside a real one is refused naming the file; a
  file whose only class key is mistyped is loaded as a flake-parts module
  and flake-parts rejects the unknown option.
- Raw `nixos-generate-config` output needs wrapping: dirs-as-categories
  refuses a file asking for a class-only argument (`pkgs`, `modulesPath`,
  ...), naming it and the fix. Older versions died with a misleading
  `infinite recursion` naming `modulesPath`.
- `git add` a new file before `nix eval`: flakes ignore untracked files.

## Membership comes from the directory

- A folder below an area is a category when a subfolder of it holds a
  module, or a file directly in it sets `folderIsCategory = true`
  (`false` opts out: `python-dev/` and `pkm/history/` keep plain-folder
  status that way). Including a category includes every module beneath it,
  nested categories too.
- A module belongs to the nearest category above it; to keep one out of a
  category, file it outside that category's tree.
- Hosts and the home aggregate are modules with `includes.<class> = [ … ];`
  outside every category: `host-config/<host>-configuration.nix`,
  `users-config/elly-home-manager.nix`. A module may include another by
  name too (`kde-desktop` includes `kde-base`).
- Another class's module is reached with `enables.<class>` and arrives as
  `enabled.<class>.<name>` (`enable-home-manager.nix`).
- `defaults.nix` is never a module: its class parts apply whenever anything
  in its folder is reached. None carries settings today.
- Not modules: `hosts.nix`, `checks.nix`, `invariants.nix`, `dev-shell.nix`,
  `nix-topology-flake.nix` -- plain flake-parts modules.
- Areas: `general-config/`, `hardware-config/`, `homelab-config/`,
  `host-config/`, `packages-config/`, `users-config/`, named so no area can
  collide with a module or category name.
- The category is how something shared stays optional: nothing here
  declares `mkEnableOption`. `kde-desktop` is the by-name variant, included
  directly while its category (`desktop-env`, which also holds `jovian`) is
  never included whole.
- Orphans (a module nothing reaches) fail `just check`: `checks.nix` sets
  dirs-as-categories' `checkOrphans = "eval"`, which throws while the
  `module-orphans` check is evaluated, so `--no-build` fails too. `just
  modules` reports untracked files and drift between wiki-lint's file-only
  reading and the evaluated graph.

## Conventions

- Read `wiki/config-structure/module-style-guide.md` before writing a new module. Its
  formatting (aligned `=` columns, why `nix fmt` isn't wired up) is
  deliberate, not a cleanup target.
- Check for an existing `programs.*` integration before hand-writing one.
- When a rename makes the old name ungreppable, say what it was on the
  declaration (`boot-durandal.nix`, `boot-cube.nix`).
- A bug recorded in a comment stays in the file; do not trim one because
  the fix landed. A comment a change strands moves to a `history` heading at
  the bottom, still standalone: facts kept, narration cut
  (`boot-durandal.nix`, `WARN-impermanence.nix`, `vscode.nix`).
- `elly` is hardcoded in `users.users.elly`, `home.username`, and
  `home-manager.users.elly`. Introducing a `nire.primaryUser`-style option
  is a separate change, not a tidy-up; `wiki/config-structure/flake-parts-port-notes.md`
  has the reasoning.
- Browsing modules, not editing them: `just history-line <file>` prints
  where the history section starts; read up to it. Editing is different:
  read the history before changing what it describes.
- Name the kind of module: *module file* (the `.nix` file), *NixOS / Home Manager / darwin module* (the value under a class key), *flake-parts module* (a plain file like `hosts.nix`). A module file is never a "flake-parts module"; `wiki/config-structure/module-files.md`, "Three kinds of module".
