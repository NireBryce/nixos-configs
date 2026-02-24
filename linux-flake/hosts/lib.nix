# Defines flake.lib.mkNixos — builds a nixosConfiguration for the given
# hostname, wiring in home-manager so `nixos-rebuild switch` also applies HM.
#
# Usage (in a host's flake-parts module):
#   flake.nixosConfigurations = self.lib.mkNixos "x86_64-linux" "nire-durandal";
#
# HM config is assembled from all den.aspects.*.homeManager modules via
# the flake-aspects transposition:  den.aspects → flake.aspects → flake.modules
# All values of config.flake.modules.homeManager are applied to users.elly.
{ inputs, config, lib, ... }:
{
  flake.lib.mkNixos = system: hostname:
    inputs.nixpkgs.lib.nixosSystem {
      # Pass all flake inputs as specialArgs so NixOS modules can receive
      # them by name (e.g. `{ import-tree, nix-index-database, ... }:`).
      specialArgs = inputs;

      modules = [
        # Wire home-manager into the NixOS build so it runs on nixos-rebuild.
        inputs.home-manager.nixosModules.home-manager

        # The host's own NixOS module (from flake.modules.nixos."<hostname>").
        config.flake.modules.nixos.${hostname}

        # HM settings shared across all users on this host.
        {
          home-manager.useGlobalPkgs   = true;
          home-manager.useUserPackages = true;

          # Aggregate every den.aspects.*.homeManager module (transposed by
          # flake-aspects into config.flake.modules.homeManager.*) into elly's
          # HM config.
          home-manager.users.elly.imports =
            builtins.attrValues config.flake.modules.homeManager;
        }
      ];
    };
}
