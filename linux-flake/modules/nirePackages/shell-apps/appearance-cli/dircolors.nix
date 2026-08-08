{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            programs.dircolors = {
                enable = true;
                enableZshIntegration = true;
                enableBashIntegration = true;
                enableFishIntegration = true;
            };
        };
}
