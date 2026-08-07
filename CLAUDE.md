# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Safety

The README's warning is real: this config enables impermanence and wipes `/root`
on boot. Never suggest installing it wholesale on a machine, and be careful with
anything touching `modules/nire/impermanence-WARN-README/` or the
`fileSystems`/`boot` options in the host hardware modules.

Secrets are sops-nix (`modules/nire/secrets/`). `secrets.yaml` is encrypted and
committed; it is not a mistake to be "fixed".

## Repo shape

Three independent flakes. Only one of them is flake-parts.

- **`linux-flake/`** — the live config, and where essentially all work happens.
  flake-parts + the dendritic pattern. Two hosts: `nire-durandal` (workstation)
  and `nire-tenacity` (handheld, Jovian/SteamOS).
- **`macos/`** — a separate, older, plain flake for `nire-lysithea`. Not
  flake-parts, and its inputs deliberately diverge (it pins `nixpkgs-unstable`,
  linux-flake pins `nixos-unstable`). Changes here do not propagate.
- **`misc/`** — not wired into any flake. Standalone modules, a rust dev-shell
  flake, util scripts. Treat as a scratch area.

Everything below is about `linux-flake/`.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere in the repo:

```sh
just check      # nix flake check -- builds both hosts' toplevels
just build      # nh os build for this host, no activation
just switch     # nh os switch (applies Home Manager too, see below)
just update     # flake update + re-check
just fmt        # see "formatting" before running this
```

For iterating, evaluate directly rather than building — it is far faster and
works on any platform:

```sh
cd linux-flake
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
nix flake check --all-systems --no-build     # evaluates every output, builds nothing
```

## Architecture: the dendritic pattern

`flake.nix` is a manifest and nothing else. `(inputs.import-tree ./modules)`
recursively imports **every** `.nix` file under `linux-flake/modules/`, so paths
carry no meaning beyond naming — files can be moved freely without editing any
import. That is the point, per the README.

**Every `.nix` file under `modules/` is a flake-parts module**, i.e. its top
level is `{ flake.modules.<class>.<name> = …; }` or similar — never a bare NixOS
or Home Manager module.

### The trap that has caused real breakage twice

Dropping a raw NixOS module into `modules/` (for example fresh
`nixos-generate-config` output) makes flake-parts try to resolve that module's
`modulesPath` argument through its own `_module.args`, and evaluation dies with
`error: infinite recursion encountered`. The fix is always to wrap it:

```nix
{ ... }:
{ flake.modules.nixos.someHardware = { config, lib, modulesPath, ... }:
{
  # ... the original module body, unchanged
}
;}
```

### Module classes are not validated

flake-parts stamps the outer attribute name onto the module as `_class`
verbatim and checks nothing. A made-up class (`flake.modules.jovian.foo`)
declares successfully and then fails much later, at import, with
`cannot be imported into a module evaluation that expects class "nixos"`.
Only `nixos`, `homeManager`, `flake` and `generic` are meaningful here.

### Aggregates merge — membership lives with the module

`flake.modules.<class>.<name>` is a `deferredModule`, so many files can define
the same aggregate and the module system merges them. This is the core idiom:
a module opts *itself* into a role, next to its own definition, rather than a
host listing everything it wants.

```nix
{ config, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.bluetooth ];

    flake.modules.nixos.bluetooth = { … };
}
```

Adding a module is therefore a **one-file change**. Do not reintroduce central
import lists. The aggregates that exist:

| class | aggregate | contents |
|---|---|---|
| `nixos` | `base` | everything both hosts get |
| `nixos` | `desktop` | `base` + durandal-only (kde, vscode, virtualization, yubikey, …) |
| `nixos` | `handheld` | `base` + tenacity-only (`boot-handheld`, `wm-jovian`) |
| `homeManager` | `ellyHomeManager` | elly's whole home config |
| `homeManager` | `pkgs-cli` / `pkgs-gui` / `pkgs-linux-utils` | one module per package, under `modules/pkgs/` |

`modules/roles.nix` declares only the hierarchy between roles. Hosts
(`modules/hosts/*/`) hold just their role, hardware module, hostname and
stateVersion. `modules/pkgs-{cli,gui,linux-utils}.nix` only attach a group to
`ellyHomeManager`; the groups are kept separate so a role can take some and not
others later.

Inside a flake module prefer **`config.flake.modules.…` over `self.modules.…`** —
same data without the round trip through flake outputs, and it avoids a class of
recursion errors.

### Home Manager is NixOS-integrated

`home-manager.users.elly` is set from the NixOS side with `useGlobalPkgs` and
`useUserPackages`. There is no `nh home switch` step and no `homeConfigurations`
output; `just switch` applies both. Consequences worth knowing:

- HM rejects `nixpkgs.*` options under `useGlobalPkgs`. `allowUnfree` comes from
  the system (`modules/nire/nix/nix-settings/`).
- `home.profileDirectory` is `/etc/profiles/per-user/elly`, not `~/.nix-profile`.
- See `linux-flake/home-manager-cutover.md` for the migration runbook.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked files, so
a new module silently does not exist and you will debug a phantom. This wastes
time every single session if forgotten.

**Development is on darwin; both hosts are `x86_64-linux`.** Evaluation works
cross-platform, building does not. `checks` is filtered by system, so
`nix flake check` on the mac exercises only the formatter — the host checks
have never run there. Claims about anything building must say so honestly.

**Verify refactors by fingerprint, not by "it still evaluates."** For any change
meant to preserve behaviour, capture the drvPath before and after:

```sh
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
```

Identical drvPath means byte-identical output. If it differs, diff the config
attribute by attribute (`environment.systemPackages` names, `systemd.services`,
`users.users`, `fileSystems`, `environment.etc`) before concluding the change is
safe — reordering module imports permutes list-valued options like
`systemPackages`, which changes the hash without changing the package set. Use a
`git worktree` at the previous commit to evaluate both sides.

## Conventions

**Formatting is deliberate.** The aligned-`=` columns throughout `modules/` are
intentional. treefmt/nixfmt is configured in `modules/formatter.nix` but
deliberately **not applied**, with `flakeCheck = false`, because running it would
flatten that style across every file. Do not run `nix fmt` casually, and match
surrounding alignment when editing.

**Namespacing**, per `notes-and-fixes.md`: `nire` is the namespace for any module
that does not need a more specific tag; start broad and narrow as things clarify.

## Repo docs worth reading

- `linux-flake/2026-08-06 changelog.md` — the flake-parts cleanup: what was
  broken, what changed, how each refactor was verified.
- `linux-flake/home-manager-cutover.md` — first-switch runbook for the HM change.
- `linux-flake/notes-and-fixes.md` — the user's own accumulated fixes and notes.
