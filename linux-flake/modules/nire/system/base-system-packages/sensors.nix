{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            environment.systemPackages = with pkgs; [
                lm_sensors # lm_sensors
            ];
        };
    };
}
