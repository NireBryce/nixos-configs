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
            durandal.fixes
            nire.amdcpu
            nire.amdgpu
            nire.boot-workstation # boot.handheld for handhelds
            nire.dev-tools
            nire.firmware-all
            nire.flatpak
            nire.font
            nire.gaming
            nire.impermanence-WARN-README
            nire.kdeconnect
            nire.networking
            nix-index-database.nixosModules.nix-index


            ./hardware-configuration.nix # todo: Figure out a better way
        ];

    
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
      networking.hostName = "nire-durandal";
    };
}
