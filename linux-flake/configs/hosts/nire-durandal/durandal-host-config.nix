{ lib, ... }:
{
    
 # Set the capability flags for this machine at the flake level
    config.my = {
        hostname = "nire-durandal";
        capabilities = {
            isBattery       = false;
            isGaming        = true;
            isHandheld      = false;
            isMinimal       = false;
            isDarwin        = false;
        };
    };
  # The NixOS module for this machine
    flake.modules.nixos.desktop = {
        system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        networking.hostName = "nire-durandal";

    };
}
