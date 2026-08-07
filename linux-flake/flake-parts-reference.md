# flake-parts behaviour used in this config

A reference for the specific flake-parts machinery this flake depends on, with
the source that backs each claim. Everything here was read out of the pinned
`inputs.flake-parts` and `inputs.treefmt-nix`, not from the website.

Companion docs: `CLAUDE.md` (working rules), `2026-08-06 changelog.md` (what was
changed and why).

---

## 1. `mkFlake` and the top-level module

`flake.nix` calls `mkFlake { inherit inputs; } { … }`. The second argument is a
flake-parts **module**, so everything in it is module-system options, not a
plain attrset:

```nix
outputs =
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; }
    {
        imports = [
            inputs.flake-parts.flakeModules.modules   # adds the flake.modules option
            (inputs.import-tree ./modules)            # every .nix under modules/
        ];
        systems = [ "x86_64-linux" "aarch64-darwin" ];
    };
```

`systems` is the list flake-parts iterates when building per-system outputs. A
system you pass to `withSystem` must be in this list. `aarch64-darwin` is here
purely so `nix fmt` works from the mac — no darwin configuration is built.

**Module arguments available at the top level:** `self`, `inputs`, `config`,
`options`, `lib`, plus flake-parts' own `withSystem`, `moduleWithSystem` and
`getSystem`. Note the reverse is not true: inside `perSystem`, `self`, `inputs`,
`getSystem`, `withSystem` and `moduleWithSystem` are all deliberately bound to
*throwing* aliases (`modules/perSystem.nix:123-127`) to stop you reaching out of
the per-system scope by accident.

---

## 2. `flake.modules` — the option this whole config is built on

Provided by `flake-parts.flakeModules.modules` (`extras/modules.nix`). The
declaration is:

```nix
type = types.lazyAttrsOf (types.lazyAttrsOf types.deferredModule);
apply = mapAttrs (k: mapAttrs (addInfo k));
```

Two consequences matter enormously here.

### 2a. The outer attribute name becomes `_class`, unvalidated

`addInfo` wraps every module (except under `generic`):

```nix
{ ... }:
{
  _class = class;
  _file = "${toString moduleLocation}#modules.${class}.${moduleName}";
  imports = [ module ];
}
```

The class string is whatever you typed. flake-parts checks nothing. So
`flake.modules.jovian.wm-jovian` declares happily and only fails later, when
something imports it into a NixOS evaluation:

```
error: The module `…/flake.nix#modules.jovian.wm-jovian` (class: "jovian")
cannot be imported into a module evaluation that expects class "nixos".
```

That `…#modules.<class>.<name>` string in the error is the generated `_file`,
which is how you locate the culprit. Meaningful classes here: `nixos`,
`homeManager`, `flake`, `generic`. `homeManager` and `darwin` work only because
those projects set the matching `_class` on their own module evaluations;
`generic` is special-cased to set no class at all, so it loads anywhere.

(The wrapper returns a *function* rather than an attrset deliberately — see the
comment citing flake-parts issue #326 — so it is still accepted as a full module
under `shorthandOnlyDefinesConfig`.)

### 2b. `deferredModule` merges, which is why membership lives with the module

Because each leaf is a `deferredModule`, **several files may define the same
attribute and the module system merges all of them into one module.** This is
the mechanism behind every aggregate in this repo. Verified directly:

```nix
# file A
flake.modules.nixos.workstation.imports = [ { networking.hostName = "a"; } ];
# file B
flake.modules.nixos.workstation.imports = [ { networking.firewall.enable = false; } ];

# nixosSystem { modules = [ res.modules.nixos.workstation ]; }
#   => { host = "a"; fw = false; }   both definitions present
```

So a feature module opts *itself* into a role, next to its own definition,
instead of a host maintaining a list:

```nix
{ config, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.bluetooth ];

    flake.modules.nixos.bluetooth = {
        hardware.bluetooth.enable      = true;
        hardware.bluetooth.powerOnBoot = true;
    };
}
```

Two modules in this repo relied on this accidentally before it was deliberate:
`flake.modules.nixos.nix` is defined across three files
(`nix-settings.nix`, `nh.nix`, `nix-output-monitor.nix`) and `dev-tools` across
two.

### 2c. `config.flake.modules` vs `self.modules`

Both resolve to the same data. Prefer `config.flake.modules.…`: `self.modules`
goes out through the flake's `outputs` and back in, which is a longer
dependency path and a common source of confusing recursion. Host configs read:

```nix
imports = with config.flake.modules.nixos; [ desktop durandalHardware ];
```

---

## 3. `perSystem` — per-system outputs

`perSystem` is a function from system to flake-like attributes with the
`<system>` level omitted. Arguments: `pkgs`, `system`, `self'`, `inputs'`,
`config`, `options`, `lib`.

- `pkgs` defaults to `inputs.nixpkgs.legacyPackages.${system}` — **with no
  config applied**, which is exactly why host `pkgs` is not taken from here
  (see §4).
- `self'` / `inputs'` are the system-preselected versions:
  `inputs'.foo = config.perInput system inputs.foo`, so `inputs'.foo.packages.bar`
  instead of `inputs.foo.packages.${system}.bar`.

This flake uses `perSystem` for exactly two things.

**`checks`** (`modules/checks.nix`) — `types.lazyAttrsOf types.package`, so each
entry must be a derivation. Forcing each host's `toplevel` turns
`nix flake check` into an evaluation test of the whole config:

```nix
{ config, lib, ... }:
{
    perSystem = { system, ... }:
    let
        hostsForThisSystem = lib.filterAttrs
            (_: host: host.config.nixpkgs.hostPlatform.system == system)
            config.flake.nixosConfigurations;
    in
    {
        checks = lib.mapAttrs'
            (name: host: lib.nameValuePair "nixos-${name}" host.config.system.build.toplevel)
            hostsForThisSystem;
    };
}
```

Note `config` here is the **top-level** config, captured by the outer function —
the inner `{ system, ... }` never binds `config`, so there is no shadowing. The
filter is what makes `nix flake check` on darwin skip the linux hosts instead of
trying to build them.

**`formatter`** via treefmt-nix's `flakeModule`, which is a third-party
flake-parts module imported like any other. Its `flake-module.nix` sets:

```nix
checks    = lib.mkIf config.treefmt.flakeCheck { … };
formatter = lib.mkIf config.treefmt.flakeFormatter (lib.mkDefault config.treefmt.build.wrapper);
```

Both default to `true`. This repo sets `flakeCheck = false` on purpose, because
the tree is not formatted yet and a failing check would be noise.

---

## 4. `withSystem` — reaching per-system scope from the top level

The implementation is three lines (`modules/withSystem.nix`):

```nix
withSystem = system: f: f (getSystem system).allModuleArgs;
```

where `allModuleArgs = config._module.args // specialArgs // { inherit config options; }`.
So `withSystem` simply applies your function to that system's `perSystem`
module arguments — `config` inside the callback is the **perSystem** config.

`modules/hosts/hosts.nix` uses it to give host modules `self'` and `inputs'`:

```nix
mkHost = system: hostModule: withSystem system ({ self', inputs', ... }:
    inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs self' inputs'; };
        modules     = [ hostModule ];
    });
```

`specialArgs` (rather than `_module.args`) is what makes these usable inside
`imports`, which is evaluated before `config`.

**Deliberately not done:** passing `nixpkgs.pkgs = pkgs` from perSystem.
perSystem's `pkgs` is bare `legacyPackages` with no `nixpkgs.config`, so sharing
it would drop `allowUnfree` and break the unfree packages these hosts install.
Letting `nixosSystem` build its own pkgs from the host's own `nixpkgs.config` is
the correct trade here, at the cost of a second nixpkgs instantiation.

---

## 5. `flake.*` — raw outputs

`flake.<attr>` writes flake outputs directly. Some attrs get dedicated modules
that type them; `flake.nixosConfigurations` is
`types.lazyAttrsOf types.raw` (`modules/nixosConfigurations.nix`) and its
docstring makes the split this repo follows explicit:

> `nixosConfigurations` is for specific machines. If you want to expose reusable
> configurations, add them to `nixosModules` in the form of modules (no
> `lib.nixosSystem`).

Here that is `flake.modules.nixos.*` for the reusable half and
`flake.nixosConfigurations.*` for the two instantiated machines.

---

## 6. `import-tree` interaction

Not flake-parts, but inseparable from how this config reads.
`(inputs.import-tree ./modules)` imports **every** `.nix` file under `modules/`
recursively as a flake-parts module, so file paths carry no meaning and files
can be moved freely. Non-`.nix` files are ignored, which is why
`modules/pkgs/**/config/*.kdl|py|.justfile` can live beside their modules.
Paths containing `/_` are excluded by default.

**The failure mode this creates:** a file under `modules/` that is a plain NixOS
module gets handed to flake-parts, which tries to resolve its `modulesPath`
argument via flake-parts' own `_module.args`, and evaluation dies:

```
… while evaluating the module argument `modulesPath' in ".../hardware-configuration.nix":
… noting that argument `modulesPath` is not externally provided, so querying `_module.args` instead
error: infinite recursion encountered
```

Always wrap: `{ ... }: { flake.modules.nixos.<name> = <the original module>; }`.

---

## 7. Available but deliberately unused

| feature | why not |
|---|---|
| `partitions` / `partitionedAttrs` | Exists to keep dev inputs out of *consuming* flakes' locks. Nothing consumes this flake. |
| `easyOverlay` | No overlays defined here. |
| `moduleWithSystem` | Would matter if a NixOS module needed `perSystem.config.packages`; nothing does. |
| `transposition` | For custom per-system output attributes; none here. |
| `debug` | Useful ad hoc (`debug = true` exposes `config` in `nix repl`), not committed. |
| `flake.overlays` / `packages` | This flake builds machines, not packages. |

---

## 8. Gotchas, ranked by how much time they cost

1. **Untracked files do not exist.** Flakes in a git repo only see tracked
   files, so a new `modules/*.nix` is silently absent until `git add`. Symptom:
   an output evaluates to `[ ]` or an attribute is "missing" for no reason.
2. **A raw module under `modules/`** → infinite recursion (§6).
3. **Class typos are not caught at the declaration** (§2a) — the error surfaces
   at the import site, and names the generated `_file`.
4. **Import order affects list-valued options.** Reordering module imports
   permutes `environment.systemPackages`, which changes the toplevel drvPath
   without changing the package set. Compare attribute-by-attribute before
   concluding a refactor broke something.
5. **`withSystem` on a system not in `systems`** fails; keep the two in sync.
