# Standalone home-manager configuration for elly on nire-durandal.
# Assembled from all den.aspects.X.homeManager modules declared in
# configs/home-manager/user-elly/, bridged via den-bridge.nix into
# config.flake.modules.homeManager.
#
# Switch with: nh home switch --configuration elly@nire-durandal ~/nixos/linux-flake/
#          or: home-manager switch --flake .#elly@nire-durandal
{ inputs, config, ... }:
{
  flake.homeConfigurations."elly@nire-durandal" =
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";

      # Pass all flake inputs so HM modules can receive them by name
      # (e.g. `{ impermanence, ... }:`).
      extraSpecialArgs = inputs;

      modules = builtins.attrValues config.flake.modules.homeManager;
    };
}
