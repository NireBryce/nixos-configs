{ self, inputs, ... }:
{ flake.modules.nixos.durandalConfiguration = 

{
    imports = with self.modules.nixos; [
        elly
        durandalHardware
        amdcpu
        amdgpu
        auth-yubikey
        bluetooth
        boot-workstation # boot.handheld for handhelds
        dev-tools
        firmware-all
        flatpak
        font
        gaming
        kdeconnect
        impermanence-WARN-README
        networking
        nix
        secrets
        shell-config
        sound-pipewire
        ssh
        storage-nfs
        system
        system-boot
        virtualization
        wayland
        wifi
        wm-kde
        xdg
        logitech-g600
        zsa-moonlander
        system-base-packages
    ];


            # TODO: having to import these is a regression even if flake-parts makes for better errors.  look into ways to auto-import things and then blacklist individual modules


    
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
      networking.hostName = "nire-durandal";
    };
}
