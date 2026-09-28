{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [
                auto-cpufreq # https://github.com/AdnanHodzic/auto-cpufreq
            ];
        };
}
