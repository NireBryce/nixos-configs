
{ amd.cpu.nixos = 
{ nixos-hardware, ... }: 
{
    imports = [ 
        nixos-hardware.nixosModules.common-cpu-amd 
    ];
}
;}
