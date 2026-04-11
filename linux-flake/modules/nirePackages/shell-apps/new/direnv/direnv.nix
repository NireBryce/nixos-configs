{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        programs.direnv = {
            enable = true;
            enableBashIntegration = true;
            enableZshIntegration = true;
            enableNushellIntegration = true;
            nix-direnv.enable = true;
        };
    };
}
