{ 
    nixos-hardware,
    ...
}:

{
    imports = [ nixos-hardware.nixosModules.common-cpu-amd ];
}
