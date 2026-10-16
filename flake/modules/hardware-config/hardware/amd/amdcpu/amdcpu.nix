# Module file: named after this file; why it looks this way: wiki/module-files.md
{ inputs, ... }:
{
    nixos = {
        imports = [
            inputs.nixos-hardware.nixosModules.common-cpu-amd
        ];
    };
}
