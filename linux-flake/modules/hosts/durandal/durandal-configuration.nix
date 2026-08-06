{ self, ... }:
{ 
    flake.modules.nixos.durandalConfiguration = 
    {
        # TODO: check these
        imports = with self.modules.nixos; [
            durandalHardware
            elly
            amdcpu
            amdgpu
            auth-yubikey
            bluetooth
            boot-workstation
            dev-tools
            firmware-all
            flatpak
            font
            gaming
            home-manager
            kdeconnect
            # impermanence-WARN-README  # see module for warnings
            networking
            nix
            secrets
            shell-config
            sound-pipewire
            ssh
            storage-nfs
            system
            system-base-packages
            virtualization
            wayland
            wifi
            wm-kde
            xdg
            logitech-g600
            zsa-moonlander
            vscode
        ];

        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion  = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        networking.hostName  = "nire-durandal";
    }; 
}
