# `nix flake check` should actually check something.
#
# Both of the bugs that broke this flake (a raw NixOS module left in the
# import-tree path, and a module declared under an invalid class) were pure
# evaluation errors. Forcing every host's toplevel derivation catches that
# class of breakage without building anything.
{ config, lib, ... }:
{
    perSystem = { system, pkgs, ... }:
    let
        hostsForThisSystem = lib.filterAttrs
            (_: host: host.config.nixpkgs.hostPlatform.system == system)
            config.flake.nixosConfigurations;

        hostChecks = lib.mapAttrs'
            (name: host: lib.nameValuePair "nixos-${name}" host.config.system.build.toplevel)
            hostsForThisSystem;
    in
    {
        checks = hostChecks // {
            # A module that never gets opted into an aggregate is valid, evaluates
            # fine, and does nothing -- so no amount of evaluating catches it.
            # Static reachability over the module tree does. Unlike the host
            # checks this is platform independent, so it is the one real check
            # that also runs on darwin.
            orphaned-modules = pkgs.runCommand "orphaned-modules"
                { nativeBuildInputs = [ pkgs.python3 ]; }
                ''
                    if ! python3 ${../scripts/modules.py} orphans ${./.} > "$out"; then
                        cat "$out" >&2
                        exit 1
                    fi
                    cat "$out"
                '';
        };
    };
}
