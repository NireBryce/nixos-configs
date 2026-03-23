{ self, inputs, ...}:
{ flake.modules.nixos.wifi = 
{ ... }:  
{
    networking.networkmanager.enable = true;        # Needs to be 'true' for KDE networking
}
;}
