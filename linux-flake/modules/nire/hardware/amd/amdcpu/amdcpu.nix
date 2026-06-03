{ 
    perSystem = {lib, inputs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            imports = [
                inputs.nixos-hardware.nixosModules.common-cpu-amd
            ];
        };
    };
}
