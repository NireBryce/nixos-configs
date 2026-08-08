{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            programs.starship = {
                enable = true;
                enableBashIntegration = true;
                enableZshIntegration = true;
                enableFishIntegration = true;
            };
        };
}
