{
    ...
}:
{ den.aspects.networking-wifi.nixos = 
{ ... }:  
{
    networking.networkmanager.enable = true;        # Needs to be 'true' for KDE networking
}
;}
