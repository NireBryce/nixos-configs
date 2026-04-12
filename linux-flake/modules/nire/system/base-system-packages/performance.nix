{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = { pkgs, ... }:
        environment.systemPackages = with pkgs; [
            auto-cpufreq    # https://github.com/AdnanHodzic/auto-cpufreq
        ];
    };
}
