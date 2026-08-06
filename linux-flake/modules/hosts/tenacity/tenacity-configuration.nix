{ config, ... }:
{
    flake.modules.nixos.tenacityConfiguration = {
        imports = with config.flake.modules.nixos; [
            handheld
            tenacityHardware
        ];

        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion  = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        networking.hostName  = "nire-tenacity";
    };
}
