# Going back to standalone Home Manager

Home Manager here is **NixOS-integrated**: `home-manager.users.elly` is set from
the NixOS side with `useGlobalPkgs` and `useUserPackages`, there is no
`homeConfigurations` output, and `nh os switch` applies both. This document is
the way back, if that turns out to be the wrong call.

It is not a recommendation to revert. It exists because the choice was made once,
quickly, and should not require re-deriving the consequences to undo.

---

## What integrated actually bought and cost

**Bought:** one switch instead of two, one nixpkgs instantiation instead of two,
and a home config that cannot drift out of sync with the system it runs on.
Before this, the den version produced `flake.homeConfigurations.elly-nire-durandal`
and the NixOS side knew nothing about it.

**Cost, concretely:**

- `useGlobalPkgs` makes Home Manager **reject** any `nixpkgs.*` option set inside
  a home module — not ignore it, error on it. `basic-nix-settings.nix` had to
  drop its homeManager `nixpkgs.config` block, and with it the
  `allowUnfreePredicate = (_: true)` workaround for home-manager issue #2942.
  `allowUnfree` now comes from the nixos side of that same file.
- `home.profileDirectory` is `/etc/profiles/per-user/elly`, not `~/.nix-profile`.
- Activation runs as the `home-manager-elly.service` systemd unit rather than
  from a login shell, so its `PATH` is only coreutils/findutils/gnugrep/gnused/
  systemd, and `QT_QPA_PLATFORM=offscreen`. Anything assuming an interactive
  environment will not see one.
- There is no way to switch home config without switching the system.

---

## The three files that would change

### 1. `modules/nire/system/home-manager/enable-home-manager.nix` — delete it

This is the whole of the integration: it imports
`inputs.home-manager.nixosModules.home-manager` and sets `home-manager.users.elly`
to `ellyHomeManager`. Nothing else references it.

It lives under `nire/system/` so the `system` category carries it to durandal.
Deleting the file removes it from that category automatically — no host edit.

### 2. `modules/nireUser/elly-home-manager.nix` — keep, and build a configuration from it

`ellyHomeManager` is the module aggregate and is **independent of how it gets
applied**. It is the same value either way; only the consumer changes. Add a
`homeConfigurations` output alongside it:

```nix
{ config, inputs, withSystem, ... }:
{
    flake.homeConfigurations.elly-nire-durandal = withSystem "x86_64-linux" ({ pkgs, ... }:
        inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = { inherit inputs; };
            modules = [ config.flake.modules.homeManager.ellyHomeManager ];
        });
}
```

Two things to get right here:

- **`pkgs` needs `allowUnfree`.** This is the trap. perSystem's default `pkgs` is
  `inputs.nixpkgs.legacyPackages.<system>`, which has no `nixpkgs.config` applied
  — and this config installs plenty of unfree packages. Either configure a pkgs
  instance explicitly for it, or restore the `nixpkgs.config` block in
  `basic-nix-settings.nix`, which standalone allows again.
- **`withSystem` requires the system to be listed in `systems`** in `flake.nix`.
  `x86_64-linux` is, today.

### 3. `modules/nire/nix/nix-settings/basic-nix-settings.nix` — restore the block

Standalone permits `nixpkgs.*` in home modules again, so this can go back:

```nix
nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true); # workaround for home-manager issue #2942
};
```

Its removal is recorded in a comment in that file, which is the intended
breadcrumb back here.

---

## Order, and the one-way part

1. Add the `homeConfigurations` output and confirm it evaluates
   (`nix eval --raw '.#homeConfigurations.elly-nire-durandal.activationPackage.drvPath'`)
   **before** removing the integration. Both can coexist; that is the safe
   overlap, and it is how this config was configured for a long time by accident
   — the NixOS side imported the HM module and never set `home-manager.users`,
   so it was inert while `homeConfigurations` did the real work.
2. Restore the `nixpkgs.config` block, or configure `pkgs` for the standalone
   configuration. Do this second, so a broken unfree evaluation is attributable.
3. Delete `enable-home-manager.nix` last.
4. Update `.justfile` and CLAUDE.md — with standalone there is a separate
   `nh home switch --configuration elly-nire-durandal` step, which integrated
   does not have.

**The one-way part is on the machine, not in the repo.** If integrated has ever
been switched to, `useUserPackages` will have removed the old `home-manager-path`
entry from the user profile (Home Manager's own `installPackages` step reduces to
`nixProfileRemove home-manager-path` under that option). Going back to standalone
re-creates a user profile from empty. That is a first-activation again, with the
collision risk that implies for any dotfile HM wants to own and finds already
present — the same risk described for the initial cutover.

---

## What does *not* change

- `ellyHomeManager` itself, and every module it imports. The whole
  `modules/nirePackages/` tree, `nire/shell-config/`, `nireUser/elly/` — all of it
  is untouched by this decision. That is the point of the aggregate being a plain
  `deferredModule`: it does not know or care who evaluates it.
- Anything about categories, `dirsAsCategory`, or the host wiring.
- The NixOS side of `basic-nix-settings.nix`, which sets `allowUnfree` for the
  system regardless.
