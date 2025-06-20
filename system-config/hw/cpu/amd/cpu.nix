{ 
    inputs,
    ...
}:

{
    imports = [ inputs.nixos-hardware.nixosModules.common-cpu-amd ];
}
