# Standalone home-manager configuration for elly on nire-durandal.
#
# Every den.aspects.X.homeManager module is collected directly from
# config.den.aspects at the flake-parts level. Aspects that declare no
# .homeManager are silently skipped. No flake-aspects transposition needed.
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

      # Collect every .homeManager module from every aspect. Aspects that only
      # define .nixos (or nothing) are filtered out via `or null`.
      modules =
        builtins.filter (m: m != null)
          (map (aspect: aspect.homeManager or null)
            (builtins.attrValues config.den.aspects));
    };
}
