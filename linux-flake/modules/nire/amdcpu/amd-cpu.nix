{ self, inputs, ... }:
{ flake.nixosModules.amdcpu = 
{ ... }:
{
    imports = [ 
        inputs.nixos-hardware.nixosModules.common-cpu-amd 
    ];
}
;}
