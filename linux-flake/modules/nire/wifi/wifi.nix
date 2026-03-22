{ self, inputs, ...}:
{ flake.nixosModules.wifi = 
{ ... }:  
{
    networking.networkmanager.enable = true;        # Needs to be 'true' for KDE networking
}
;}
