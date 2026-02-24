# Defines flake.lib.mkNixos — builds a nixosConfiguration from ALL transposed
# nixos aspects.
#
# Every den.aspects.X.nixos module (bridged via den-bridge.nix into
# config.flake.modules.nixos.X) is included, so system-config aspects
# (gaming, sound, wayland, etc.) apply automatically alongside the
# host-specific aspect that sets hostname/stateVersion/hw-conf.
#
# Home-manager is now standalone — see hosts/nire-durandal/elly-home.nix.
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

      # Include every nixos aspect declared across configs/system-config/ and
      # the host-specific module from durandal-host-config.nix.
      modules = builtins.attrValues config.flake.modules.nixos;
    };
}
