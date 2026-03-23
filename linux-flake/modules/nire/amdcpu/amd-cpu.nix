{ self, inputs, ... }:
{ flake.modules.nixos.amdcpu = 
{ ... }:
{
    imports = [ 
        inputs.nixos-hardware.nixosModules.common-cpu-amd 
    ];
}
;}
