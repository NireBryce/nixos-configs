# `nix flake check` should actually check something.
#
# Both of the bugs that broke this flake (a raw NixOS module left in the
# import-tree path, and a module declared under an invalid class) were pure
# evaluation errors. Forcing every host's toplevel derivation catches that
# class of breakage without building anything.
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
