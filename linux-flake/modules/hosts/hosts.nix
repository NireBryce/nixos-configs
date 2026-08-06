{ config, inputs, withSystem, ... }:
let
    # withSystem enters flake-parts' per-system scope, which is what makes the
    # system-preselected `self'` / `inputs'` available to host modules. pkgs is
    # deliberately *not* taken from perSystem: nixosSystem builds its own from
    # the host's nixpkgs.config (allowUnfree etc.), and perSystem's default
    # legacyPackages instance has none of that applied.
    mkHost = system: hostModule: withSystem system ({ self', inputs', ... }:
        inputs.nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs self' inputs'; };
            modules     = [ hostModule ];
        });
in
{
    flake.nixosConfigurations = {
        nire-durandal = mkHost "x86_64-linux" config.flake.modules.nixos.durandalConfiguration;
        nire-tenacity = mkHost "x86_64-linux" config.flake.modules.nixos.tenacityConfiguration;
    };
}
