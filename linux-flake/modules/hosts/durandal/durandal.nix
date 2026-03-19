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
            # TODO: having to import these is a regression even if it makes for better errors
            # TODO: look into ways of having den auto-import things and then blacklist individual modules


            users.elly
            hosts.durandal # todo: Figure out a better way
            nire.amdcpu
            nire.amdgpu
            nire.avahi
            nire.boot-workstation # boot.handheld for handhelds
            nire.dev-tools
            nire.firmware-all
            nire.flatpak
            nire.font
            nire.gaming
            nire.impermanence-WARN-README
            nire.kdeconnect
            nire.networking
            nire.nix
            nire.shell-bash
            nire.shell-config
            nire.shell-fish
            nire.shell-zsh
            nire.sound-pipewire
            nire.ssh
            nire.storage-nfs
            nire.system
            nire.virtualization
            nire.wayland
            nire.wifi
            nire.wm-kde
            nire.xdg
            packages.linux
            nix-index-database.nixosModules.nix-index
            peripherals.logitech-g600
            peripherals.zsa-moonlander
        ];

    
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
      networking.hostName = "nire-durandal";
    };
}
