{ config, ... }:
{
    flake.modules.nixos.durandalConfiguration = {
        imports = with config.flake.modules.nixos; [
            desktop
            durandalHardware
            impermanence-WARN-README  # see module for warnings
        ];

        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion  = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        networking.hostName  = "nire-durandal";
    };
}
