# Defines flake.lib.mkNixos — builds a nixosConfiguration from all nixos
# aspects declared across configs/.
#
# Every den.aspects.X.nixos module is collected directly from config.den.aspects
# at the flake-parts level. Aspects that declare no .nixos are silently skipped.
# No flake-aspects transposition or den includes/resolve needed.
#
# TRADEOFF: all nixos aspects are included unconditionally regardless of
# hostname. Host-specific behaviour should be gated inside the module itself
# with lib.mkIf (config.networking.hostName == "…").
#
# Home-manager is standalone — see hosts/nire-durandal/elly-home.nix.
#
# Usage (in a host's flake-parts module):
#   flake.nixosConfigurations."nire-durandal" = self.lib.mkNixos "x86_64-linux" "nire-durandal";
{ inputs, config, ... }:
{
  flake.lib.mkNixos = _system: _hostname:
    inputs.nixpkgs.lib.nixosSystem {
      # Pass all flake inputs as specialArgs so NixOS modules can receive
      # them by name (e.g. `{ impermanence, nix-index-database, ... }:`).
      specialArgs = inputs;

      # Collect every .nixos module from every aspect. Aspects that only
      # define .homeManager (or nothing) are filtered out via `or null`.
      modules =
        builtins.filter (m: m != null)
          (map (aspect: aspect.nixos or null)
            (builtins.attrValues config.den.aspects));
    };
}
