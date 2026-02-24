# Defines flake.lib.mkNixos — builds a nixosConfiguration from all nixos
# aspects declared across configs/.
#
# flake-aspects transposes den.aspects.X.nixos → flake.modules.nixos.X at
# flake-parts evaluation time (via den-bridge.nix + flake-aspects.flakeModule
# in outputs.nix). Using the already-resolved flake.modules here avoids
# triggering den's internal resolve machinery inside the NixOS evaluation
# context, which causes infinite recursion in den's recursive providerType
# description when nix flake check force-evaluates _module.args.den.
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

      # All nixos aspects, already resolved to plain module values by
      # flake-aspects at flake-parts time.
      modules = builtins.attrValues config.flake.modules.nixos;
    };
}
