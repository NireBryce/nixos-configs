{ self, inputs, ... }:
{ flake.nixosModules.amdcpu = 
{ inputs, ... }: 
{
    imports = [ 
        inputs.nixos-hardware.nixosModules.common-cpu-amd 
    ];
}
;}
