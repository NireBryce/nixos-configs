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
# flake-parts module rather than a module file
# (wiki/config-structure/module-files.md).
{ config, lib, ... }:
{
    # checks.<system>.module-orphans: fails naming any module inside a
    # category that no `includes`/`enables` reaches (wiki/config-structure/module-files.md).
    # "eval" throws while the check is evaluated, so `just check`
    # (--no-build) fails on it; "build" would fail only when built, which
    # --no-build never does. The throw comes from the check attribute, not
    # from flake.moduleGraph, so `modules.py` can still read the graph of a
    # tree that has an orphan.
    dirsAsCategories.checkOrphans = "eval";

    # checks.<system>.module-class-contents: names a class part that sets a
    # namespace only another class has (`home` under `nixos`). "eval" for the
    # same --no-build reason as orphans.
    dirsAsCategories.checkClassContents = "eval";

    perSystem = { system, pkgs, ... }:
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

        # The helpers in flake.lib are pure, so they can be checked against
        # hand-made configs. The mkIf conditions are what a host would see.
        L     = config.flake.lib;
        host  = { restore ? false, volume ? false }: {
            boot.initrd.systemd.services = if restore then { restore-root = { }; } else { };
            nire.hasPersistVolume        = volume;
        };
        cond  = x: x.condition;
        libTestFailures = lib.runTests {
            testImpermanentYes = {
                expr = cond (L.persist.persistIfImpermanent (host { restore = true; }) { }); expected = true;
            };
            testImpermanentNo = {
                expr = cond (L.persist.persistIfImpermanent (host { }) { }); expected = false;
            };
            # cube: a /persist volume and no wipe
            testRegardlessWithVolume = {
                expr = cond (L.persist.persistRegardless (host { volume = true; }) { }); expected = true;
            };
            testRegardlessWithoutVolume = {
                expr = cond (L.persist.persistRegardless (host { }) { }); expected = false;
            };
            testPersistTarget = {
                expr = (L.persist.persistIfImpermanent (host { restore = true; }) { files = [ "/f" ]; }).content;
                expected = { environment.persistence."/persist".files = [ "/f" ]; };
            };
            testTailnetName = { expr = L.fleet.tailnetName "nire-cube"; expected = "ts-cube"; };
            testBaseHostnames = {
                expr = L.fleet.baseHostnames [ "nire-a" "forge-runner" "nire-b" ]; expected = [ "nire-a" "nire-b" ];
            };
        };
    in
    {
        # `just check` is `nix flake check --no-build`, which evaluates a check
        # and never runs its builder, so a check that fails by `exit 1` in a
        # builder cannot fail there (invariants.nix explains the same trap).
        # lib-helpers therefore throws during evaluation. Orphans -- modules
        # nothing reaches, which evaluate and install nothing -- are
        # dirs-as-categories' own check, `module-orphans`, turned on at the top
        # of this file in its "eval" mode, which throws while the check is
        # evaluated and so fails here too. `just modules` covers what the
        # library does not: untracked files and drift against wiki-lint's
        # reading.
        checks = hostChecks // homeChecks // {
            lib-helpers =
                if libTestFailures == [ ] then pkgs.runCommand "lib-helpers" { } "touch $out"
                else throw "lib-helpers: ${builtins.toJSON libTestFailures}";
        };
    };
}
