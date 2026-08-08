{ config, inputs, withSystem, ... }:
let
    # withSystem enters flake-parts' per-system scope, which is what makes the
    # system-preselected `self'` / `inputs'` available to host modules.
    #
    # `pkgs` is deliberately NOT taken from perSystem: nixosSystem builds its own
    # from the host's own nixpkgs.config, and perSystem's default
    # legacyPackages.<system> instance has none of that applied -- taking it from
    # there would silently drop allowUnfree, which this config depends on.
    mkHost = system: hostModule: withSystem system ({ self', inputs', ... }:
        inputs.nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs self' inputs'; };
            modules     = [ hostModule ];
        });
in
{
    flake.nixosConfigurations = {
        nire-durandal = mkHost "x86_64-linux" config.flake.modules.nixos.durandalConfiguration;
    };
}
