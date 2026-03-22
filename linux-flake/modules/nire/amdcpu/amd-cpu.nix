{ self, inputs, ... }:
{ flake.nixosModules.amdcpu = 
{ nixos-hardware, ... }: 
{
    imports = [ 
        nixos-hardware.nixosModules.common-cpu-amd 
    ];
}
;}
