{ lib, ... }:
{
    
 # Set the capability flags for this machine at the flake level
    config.my.roles = {
        develop     = true;
        gaming      = true;
        notMinimal  = true;
        amdCpu      = true;
        amdGpu      = true;
    };
  # The NixOS module for this machine
    flake.modules.nixos.nire-durandal = {
        system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        networking.hostName = "nire-durandal";

    };
}
