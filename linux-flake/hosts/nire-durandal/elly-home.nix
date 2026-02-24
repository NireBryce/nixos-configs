# Standalone home-manager configuration for elly on nire-durandal.
#
# flake-aspects transposes den.aspects.X.homeManager → flake.modules.homeManager.X
# at flake-parts evaluation time. Using flake.modules here (rather than
# accessing config.den.aspects directly) avoids the infinite recursion in
# den's recursive providerType description triggered during nix flake check.
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

      # All homeManager aspects, already resolved by flake-aspects.
      modules = builtins.attrValues config.flake.modules.homeManager;
    };
}
