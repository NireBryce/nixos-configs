{
    ...
}:
{ den.aspects.nixos.provides.networking-wifi = 
{ ... }:  
{
    networking.networkmanager.enable = true;        # Needs to be 'true' for KDE networking
}
;}
