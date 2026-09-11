# flake-parts port notes, for agents

_Last modified: 2026-09-11_

Condensed from [flake-parts-port-notes.md](flake-parts-port-notes.md), which
keeps the salvage story, the decision reasoning and the upstream file/line
citations behind each claim. Facts only here.

Salvaged 2026-09-08 from the deleted `flake-parts` branch (tip `cf9aea42`).

## Decisions that are still load-bearing

Each was an explicit choice, not a default. Re-deciding them silently is
worse than either answer.

- **Home Manager NixOS-integrated**, not standalone.
  `nire/system/home-manager/enable-home-manager.nix`;
  [`../flake/doc/trailhead-home-manager-standalone.md`](<../flake/doc/trailhead-home-manager-standalone.md>)
  is the way back.
- **Package parity across hosts** — no role split. The handheld gets the full
  desktop GUI set on purpose.
- **starship for every shell**; powerlevel10k and its 1,659-line config
  deleted.
- **Full per-file dendritic conversion** of package modules, boilerplate
  accepted. That is why `nirePackages/` is one file per package.
- **The grep-trail convention**, since promoted into `AGENTS.md`.
- Roles `base`/`desktop`/`handheld` — **superseded** by `dirsAsCategory`
  categories.

**den and flake-aspects were never evaluated, tried, or rejected.** They
were commented out before that session began. Plain flake-parts +
`import-tree` is a feasibility data point *without* den, not an argument
against it.

## Traps that produced no error, or named the wrong thing

- **The two `config`s.** A bare-attrset module's `config` is the flake-parts
  one; adding an argument list to reach the NixOS `config` silently repoints
  every existing `config` in the file and `config.flake.modules.*` stops
  resolving. Bind what you need from the outer scope in a `let` above the
  declaration.
- **`useGlobalPkgs` makes HM reject `nixpkgs.*` outright.**
  `home.profileDirectory` moves to `/etc/profiles/per-user/<user>`, and
  activation's `PATH` is only coreutils/findutils/gnugrep/gnused/systemd with
  `QT_QPA_PLATFORM=offscreen`. Skill `home-manager-dotfiles` owns this.
- **Read the generated dotfile, not the module.** starship's init landed at
  line 2025 of `.zshrc` and ran last; p10k's 1,660 lines at 289–1991 did
  nothing, for a whole session, invisibly.
- **`home.file.<n>.text` is `types.lines`** — it concatenates, not overrides.
  One owning module per generated file.
- **`ble-import` with an absolute path needs the `.bash` extension** — the
  extension fallback applies only to relative module names. All five imports
  would have failed silently. Caught by reading source.
- **`modules.py`'s `tree` and `orphans` use different edge models on
  purpose.** Segment-scoped edges reported 119 of 160 modules as orphans,
  because a name bound in a `let` above the first declaration belongs to no
  segment. Don't unify them.
- **Omit an opt-in line and *nothing happens*** — valid Nix, clean eval,
  installs nothing, no error possible. Hence the orphan check as a flake
  check.

## flake-parts machinery

Read out of the pinned `flake-parts`, re-verified 2026-09-08.

- **`flake.modules` is
  `lazyAttrsOf (lazyAttrsOf deferredModule)`**, declared in
  `extras/modules.nix`. The outer attribute name becomes `_class`,
  **unvalidated** — a wrong class declares happily and fails at the import
  site, with an error naming the generated `_file`, i.e. its own declaration
  site. Meaningful classes: `nixos`, `homeManager`, `flake`, `generic`
  (special-cased to set no class, so it loads anywhere). `darwin` works
  because nix-darwin sets the matching `_class`.
- **`deferredModule` merges.** Several files defining the same attribute are
  merged, not conflicted — the mechanism behind every category here, and
  behind the copy-paste collision trap.
- **Prefer `config.flake.modules.…` over `self.modules.…`** — same data, but
  `self.modules` routes out through `outputs` and back, a common source of
  confusing recursion.
- **`perSystem`'s `pkgs` has no config applied** (plain
  `legacyPackages.${system}`), which is why host `pkgs` never comes from
  there. Inside it, `self`/`inputs`/`getSystem`/`withSystem`/
  `moduleWithSystem` are bound to *throwing* aliases.
- `inputs'.foo.packages.bar`, not `inputs.foo.packages.${system}.bar`.
- **`checks` entries must be derivations**, which is what lets
  `modules/checks.nix` make `nix flake check` an eval test of every host by
  forcing `system.build.toplevel`. Filtering on
  `nixpkgs.hostPlatform.system` is what makes a darwin run skip Linux hosts.
- **`withSystem system f`**: `config` inside the callback is the **perSystem**
  config. `hosts.nix` uses it for one thing — getting `self'`/`inputs'` into
  `specialArgs`, which (unlike `_module.args`) is usable inside `imports`.
  **Fails on a system not in `systems`.**
- **Deliberately not done: `nixpkgs.pkgs = pkgs` from perSystem** — it would
  drop `allowUnfree`. The cost accepted instead is a second nixpkgs
  instantiation.
- **`import-tree`** imports every `.nix` file under `modules/` recursively, so
  paths carry no meaning to Nix. Non-`.nix` files ignored; paths containing
  `/_` excluded (which is what makes `_lib/` work).
- **A plain NixOS module left unwrapped under `modules/` dies with `infinite
  recursion` blaming `modulesPath`** — nothing in the error is the cause.
  Always wrap: `{ ... }: { flake.modules.nixos.<name> = <module>; }`. Skill
  `new-flake-module`.
- `flake.nixosConfigurations` is for **specific machines**; reusable
  configurations go in `flake.modules.nixos.*` as modules, per its own
  docstring.

## See also

[flake-parts-port-notes.md](flake-parts-port-notes.md) ·
[flake-parts.md](flake-parts.md) · [architecture.md](architecture.md) ·
[lessons-learned.md](lessons-learned.md) §§1–18
