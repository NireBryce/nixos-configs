# flake.lib.mkNixos — assembles a nixosSystem from all declared aspects.
#
# By the time this runs, flake-aspects has already transposed every
#   den.aspects.<name>.nixos = { ... }: { ... };
# declaration into an entry in config.flake.modules.nixos:
#   flake.modules.nixos.<name> = <resolved module>
#
# builtins.attrValues collects all of those module values into a list,
# which becomes the `modules` argument to nixosSystem. The result is that
# every aspect file automatically contributes to every host's config —
# no host needs to explicitly list which aspects it wants.
#
# specialArgs = inputs
#   Passes all flake inputs as extra arguments to every NixOS module.
#   This is what lets individual modules receive inputs by name:
#     { impermanence, nix-index-database, ... }: { imports = [ impermanence.nixosModule ]; }
#   Without this, modules would have no way to access flake inputs.
#
# Usage (in a host file):
#   flake.nixosConfigurations."nire-durandal" = inputs.self.lib.mkNixos "x86_64-linux" "nire-durandal";
{ inputs, config, ... }:
{
  flake.lib.mkNixos = _system: _hostname:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = inputs;
      modules = builtins.attrValues config.flake.modules.nixos;
    };
}
