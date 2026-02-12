{ 
    ...
}:
{ den.aspects.nixos.provides.hw-amd-cpu = 
{ nixos-hardware, ... }: 
{
    imports = [ 
        nixos-hardware.nixosModules.common-cpu-amd 
    ];
}
;}
