{ config, inputs, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.amdcpu ];

    flake.modules.nixos.amdcpu = 
{ ... }:
{
    imports = [ 
        inputs.nixos-hardware.nixosModules.common-cpu-amd 
    ];
}
;}
