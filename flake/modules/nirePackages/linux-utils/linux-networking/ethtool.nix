{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # ethtool https://www.kernel.org/pub/software/network/ethtool/
            home.packages = with pkgs; [
                ethtool
            ];
        };
}
