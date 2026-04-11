{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        environment.systemPackages = with pkgs; [
            auto-cpufreq    # https://github.com/AdnanHodzic/auto-cpufreq
        ];
    };
}
