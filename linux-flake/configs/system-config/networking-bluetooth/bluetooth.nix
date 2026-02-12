{
    ...
}:
{ den.aspects.nixos.provides.networking-bluetooth = 
{ ... }:  
{
    hardware.bluetooth.powerOnBoot   = true;
    hardware.bluetooth.enable        = true;
    hardware.bluetooth.settings      = {
        General = {
            FastConnectable     = true;
            DiscoverableTimeout = 60; # seconds
            PairableTimeout     = 60; # seconds
        };
    };
}
;}
