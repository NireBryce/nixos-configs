---
paths:
  - "flake/modules/**"
  - "flake/flake.nix"
---

# Writing, renaming, or browsing flake-parts modules

Full mechanism and worked examples: skill `new-flake-module`.

## Module shape

- Every `.nix` file under `flake/modules/` is a flake-parts module, top
  level `{ flake.modules.<class>.<name> = …; }` or similar, never a bare
  NixOS or Home Manager module. `flake.modules` cannot live inside
  `perSystem` (no `<system>` axis, no `freeformType` there).
- A module's declared name comes from its filename, so a rename silently
  drops it from its category if the two disagree. Two modules sharing a
  name **merge** rather than conflict, since module names share one
  namespace per class. `just modules` catches both.
- Module classes aren't validated at declaration; a wrong one fails at the
  import site.
- Raw `nixos-generate-config` output needs wrapping, or evaluation dies
  with a misleading `infinite recursion` naming `modulesPath`.
- `git add` a new file before `nix eval`: flakes ignore untracked files.

## Membership comes from the directory

Read `flake/doc/dirsAsCategory.md` before changing any `dirsAsCategory.nix`.

- Each category directory's `dirsAsCategory.nix` (a shim over
  `flake/modules/_lib/category-collector.nix`) collects every `.nix` file
  under its directory at any depth, including files directly beside it. A
  module belongs to the category of the directory it is filed in; to keep
  one out, file it outside the category's tree.
- Entry points sit outside every category tree: `modules/checks.nix`,
  `modules/invariants.nix`, `host-config/hosts.nix` and the
  `<host>-configuration.nix` files beside it, and
  `users-config/elly-home-manager.nix`. `just modules` relies on this.
- Areas: `general-config/`, `host-config/`, `packages-config/`,
  `users-config/` (formerly `hosts/`, `packages/`, `users/`), named so no
  area can collide with a module or category name.
- The category is how something shared stays optional: nothing here
  declares `mkEnableOption`. `kde-desktop` is the by-name variant, imported
  directly while its category (`desktop-env`, which also holds `jovian`) is
  never imported whole.

## Conventions

- Read `wiki/module-style-guide.md` before writing a new module. Its
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
  is a separate change, not a tidy-up; `wiki/flake-parts-port-notes.md`
  has the reasoning.
- Browsing modules, not editing them: `just history-line <file>` prints
  where the history section starts; read up to it. Editing is different:
  read the history before changing what it describes.
