{ inputs, ... }:
{
    flake.modules.nixos.nire-durandal = {
        modulesPath,
        config,
        lib,
        nix-index-database,
        ...
    }:
    {
        imports = with inputs.self.modules.nixos; [
            nix-index-database.nixosModules.nix-index
            durandal.fixes
            ./hardware-configuration.nix # todo: Figure out a better way
        ];

    
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
      networking.hostName = "nire-durandal";
    };
}
