{ self, ... }:
{ flake.modules.nixos.tenacityConfiguration =
{
    imports = with self.modules.nixos; [
        tenacityHardware
        elly
        amdcpu
        amdgpu
        bluetooth
        boot-handheld
        firmware-all
        font
        gaming
        home-manager
        networking
        nix
        secrets
        shell-config
        sound-pipewire
        ssh
        system
        system-base-packages
        wayland
        wifi
        xdg
        self.modules.jovian.wm-jovian
    ];

    nixpkgs.hostPlatform = "x86_64-linux";
    system.stateVersion  = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    networking.hostName  = "nire-tenacity";
}; }
