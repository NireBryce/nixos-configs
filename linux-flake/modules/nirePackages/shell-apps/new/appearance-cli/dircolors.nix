{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        programs.dircolors = {
            enable = true;
            enableZshIntegration = true;
            enableBashIntegration = true;
            enableFishIntegration = true;
        };
    };
}
