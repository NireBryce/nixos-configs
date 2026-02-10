{ 
    ...
}:
{
den.bundles.hw.provides.amdcpu = {nixos-hardware, ...}: 
{
    imports = [ 
        nixos-hardware.nixosModules.common-cpu-amd 
    ];
}
;}
