{ self, inputs, ...}:
{ flake.nixosModules.networking =
{ ... }:  
{
    # TODO: why this DNS
    networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];
}
;}
