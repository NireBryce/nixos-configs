{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        environment.systemPackages = with pkgs; [
            lm_sensors                    # lm_sensors 
        ];
    };
}
