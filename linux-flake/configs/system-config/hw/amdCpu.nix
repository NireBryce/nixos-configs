{ 
    config,
    lib,
    ...
}:
let
  enabled = builtins.elem "amdCpu" (config.my.roles or []);
in
{
    flake.modules.nixos.hw.cpu.amd = { nixos-hardware, ... }: {
        config = lib.mkIf enabled {
            imports = [ nixos-hardware.nixosModules.common-cpu-amd ];
        };
            
    };
}
