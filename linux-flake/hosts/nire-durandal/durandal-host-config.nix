# note: may need to be inputs and then inputs.self, see https://github.com/Doc-Steve/dendritic-design-with-flake-parts/blob/main/modules/hosts/homeserver%20%5BN%5D/flake-parts.nix
{ 
    inputs,
    ... 
}:
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
