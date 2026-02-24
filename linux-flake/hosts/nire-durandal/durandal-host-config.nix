# Host aspect for nire-durandal.
#
# Every den.aspects.X.nixos module across configs/ is automatically included
# in this host's NixOS build — no explicit includes list needed. See lib.nix.
#
# TRADEOFF: because all aspects are collected unconditionally, there is no
# per-host filtering at this level. If a future aspect should only apply to
# one specific host, gate it inside the module with:
#   lib.mkIf (config.networking.hostName == "nire-durandal") { … }
{ inputs, ... }:
{
  flake.nixosConfigurations."nire-durandal" = inputs.self.lib.mkNixos "x86_64-linux" "nire-durandal";

  den.aspects."nire-durandal".nixos =
    { nix-index-database, ... }:
    {
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
      networking.hostName = "nire-durandal";

      imports = [
        nix-index-database.nixosModules.nix-index
        (inputs.import-tree ./hw-conf)
        (inputs.import-tree ./fixes)
      ];
    };
}
