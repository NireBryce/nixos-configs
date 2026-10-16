# `nix flake check` should actually check something.
#
# Everything that broke this branch was an evaluation error, and every one of
# them hid behind the previous: a raw `perSystem` wrapper, then bare strings in
# `imports`, then a duplicate dynamic attribute, then a nixos module full of
# home-manager options. Evaluating a cheap attribute proves nothing --
# `networking.hostName` resolved happily through most of that. Forcing each
# host's toplevel derivation is what catches the class, and it builds nothing.
#
# A function asking for `config`, so dirs-as-categories loads it as a plain
# flake-parts module rather than a module file (wiki/module-files.md).
{ config, lib, ... }:
{
    # checks.<system>.module-orphans: fails naming any module inside a
    # category that no `includes`/`enables` reaches (wiki/module-files.md).
    dirsAsCategories.checkOrphans = true;

    perSystem = { system, ... }:
    let
        # Both host classes, each filtered to the system it evaluates under.
        # nix-darwin sets nixpkgs.hostPlatform the same way NixOS does, so one
        # filter serves both. darwinConfigurations is not an output
        # `nix flake check` knows -- it prints "checking flake output
        # 'darwinConfigurations'" and evaluates nothing inside it -- so until
        # 2026-09-29 a lysithea-only evaluation error passed `just check`
        # green (shown by breaking general-config/macos/shells/shells.nix);
        # the only thing that forced lysithea was a hand-run eval.
        hostsOf = lib.filterAttrs
            (_: host: host.config.nixpkgs.hostPlatform.system == system);
        nixosHosts  = hostsOf config.flake.nixosConfigurations;
        darwinHosts = hostsOf config.flake.darwinConfigurations;

        # Same attribute on both classes. `nixos-`/`darwin-` in the check
        # name says which class failed.
        toplevels = prefix: lib.mapAttrs'
            (name: host: lib.nameValuePair "${prefix}-${name}" host.config.system.build.toplevel);
        hostChecks = toplevels "nixos" nixosHosts // toplevels "darwin" darwinHosts;

        # The home config is only reachable through the host that owns it, so a
        # check on the toplevel does force it -- but naming it separately makes a
        # home-only breakage say so instead of failing as "the host".
        #
        # Filtered to hosts that actually have home-manager, same gate
        # invariants.nix's usesHomeManager uses and for the same reason: a
        # host with no `elly` user and no home-manager closure never imports
        # enable-home-manager.nix, so `host.config.home-manager` is a missing
        # attribute there rather than an empty one -- true today of
        # forge-runner (the guest VM cube runs), and of nire-installer and
        # nire-llm-sandbox before their removal (2026-08-27, 2026-08-28).
        # Host names differ across the two classes today (hosts.nix); a name
        # in both would make the `//` below keep only the darwin home check.
        homeChecks = lib.mapAttrs'
            (name: host: lib.nameValuePair "home-${name}"
                host.config.home-manager.users.elly.home.activationPackage)
            (lib.filterAttrs (_: host: host.config ? home-manager) (nixosHosts // darwinHosts));
    in
    {
        # Orphans -- modules nothing reaches, which evaluate and install
        # nothing -- are dirs-as-categories' own check, `module-orphans`,
        # turned on at the top of this file; `just modules` runs the rest (untracked files,
        # drift against wiki-lint's reading).
        checks = hostChecks // homeChecks;
    };
}
