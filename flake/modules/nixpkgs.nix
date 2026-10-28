# perSystem's `pkgs` with the fleet's nixpkgs configuration applied.
# flake-parts' default is `legacyPackages.<system>`, which has no
# `nixpkgs.config`, so an unfree package would be refused in a check or dev
# shell that a host builds fine. The configuration is `flake.lib.nixpkgs.config`
# (_lib/nixpkgs.nix).
#
# Hosts still build their own nixpkgs instance (hosts.nix explains why): this
# shares the policy, not the instance.
#
# A plain flake-parts module, not a module file: it asks for `config`.
{ config, inputs, ... }:
{
    perSystem = { system, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config = config.flake.lib.nixpkgs.config;
        };
    };
}
