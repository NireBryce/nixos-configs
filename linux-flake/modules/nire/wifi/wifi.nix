{ config, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.wifi ];

    flake.modules.nixos.wifi = 
{ ... }:  
{
    networking.networkmanager.enable = true;        # Needs to be 'true' for KDE networking
}
;}
