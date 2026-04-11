{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "`tree` alternative";
        programs.broot = {
            enable  = true;
            enableZshIntegration    = true;
            enableBashIntegration   = true;
            enableFishIntegration   = true;
        };
    };
}
