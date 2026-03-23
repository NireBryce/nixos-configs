{ self, inputs, ... }:
{ flake.modules.nixos.durandalConfiguration = 

{
    imports = [
        self.modules.nixos.elly
        self.modules.nixos.durandalHardware
        self.modules.nixos.amdcpu
        self.modules.nixos.amdgpu
        self.modules.nixos.auth-yubikey
        self.modules.nixos.bluetooth
        self.modules.nixos.boot-workstation # boot.handheld for handhelds
        self.modules.nixos.dev-tools
        self.modules.nixos.firmware-all
        self.modules.nixos.flatpak
        self.modules.nixos.font
        self.modules.nixos.gaming
        self.modules.nixos.kdeconnect
        self.modules.nixos.impermanence-WARN-README
        self.modules.nixos.networking
        self.modules.nixos.nix
        self.modules.nixos.secrets
        self.modules.nixos.shell-config
        self.modules.nixos.sound-pipewire
        self.modules.nixos.ssh
        self.modules.nixos.storage-nfs
        self.modules.nixos.system
        self.modules.nixos.virtualization
        self.modules.nixos.wayland
        self.modules.nixos.wifi
        self.modules.nixos.wm-kde
        self.modules.nixos.xdg
        self.modules.nixos.logitech-g600
        self.modules.nixos.zsa-moonlander
        self.modules.nixos.system-base-packages
    ];


            # TODO: having to import these is a regression even if flake-parts makes for better errors.  look into ways to auto-import things and then blacklist individual modules


    
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
      networking.hostName = "nire-durandal";
    };
}
