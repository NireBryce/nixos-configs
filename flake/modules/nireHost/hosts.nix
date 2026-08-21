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

    # Same shape and same reasoning as mkHost -- pkgs not taken from perSystem,
    # for the same allowUnfree reason -- just calling darwinSystem instead of
    # nixosSystem. darwinSystem's own signature (nix-darwin's flake.nix) takes
    # `modules` and forwards anything else through, same as nixosSystem, so
    # `specialArgs` works identically.
    mkDarwinHost = system: hostModule: withSystem system ({ self', inputs', ... }:
        inputs.darwin.lib.darwinSystem {
            specialArgs = { inherit inputs self' inputs'; };
            modules     = [ hostModule ];
        });
in
{
    flake.nixosConfigurations = {
        nire-durandal = mkHost "x86_64-linux" config.flake.modules.nixos.durandalConfiguration;
        nire-tenacity = mkHost "x86_64-linux" config.flake.modules.nixos.tenacityConfiguration;
        nire-testbed  = mkHost "x86_64-linux" config.flake.modules.nixos.testbedConfiguration;
        nire-lego     = mkHost "x86_64-linux" config.flake.modules.nixos.legoConfiguration;
        nire-cube     = mkHost "x86_64-linux" config.flake.modules.nixos.cubeConfiguration;

        # Not a machine anyone owns -- a live-USB installer image, built to
        # install nire-testbed onto real hardware. See
        # nireHost/installer/installer-configuration.nix and the doc next to it.
        nire-installer = mkHost "x86_64-linux" config.flake.modules.nixos.installerConfiguration;
    };

    flake.darwinConfigurations = {
        nire-lysithea = mkDarwinHost "aarch64-darwin" config.flake.modules.darwin.lysitheaConfiguration;
    };
}
