# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ inputs, ... }:
{
    nixos = {
        imports = [
            inputs.nixos-hardware.nixosModules.common-cpu-amd
        ];
    };
}
