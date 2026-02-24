# Standalone home-manager configuration for elly on nire-durandal.
#
# den.aspects.elly.resolve { class = "homeManager"; } traverses elly's
# includes list transitively and collects every .homeManager module it finds.
# The actual config lives in configs/home-manager/user-elly/; the elly aspect
# in durandal-host-config.nix pulls it all in via dynamic includes.
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

      # Resolve the elly aspect: collects .homeManager from all transitively
      # included aspects. Aspects with no .homeManager are ignored.
      # resolve returns a single merged module (a set), so wrap it in a list.
      modules = [ (config.den.aspects.elly.resolve { class = "homeManager"; }) ];
    };
}
