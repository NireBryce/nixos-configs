# Defines flake.lib.mkNixos — builds a nixosConfiguration by resolving the
# host's root aspect through den's native resolution mechanism.
#
# den.aspects.${hostname}.resolve { class = "nixos"; } traverses the aspect's
# includes list transitively and collects every .nixos module it finds, so
# system-config aspects (gaming, sound, wayland, …) are included automatically
# alongside the host-specific aspect that sets hostname/stateVersion/hw-conf.
#
# The includes list is declared dynamically in each host file (see
# durandal-host-config.nix) — no flake-aspects transposition needed.
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

      # Resolve the host aspect: collects .nixos from the root aspect and all
      # transitively included aspects. Aspects with no .nixos are ignored.
      modules = config.den.aspects.${_hostname}.resolve { class = "nixos"; };
    };
}
