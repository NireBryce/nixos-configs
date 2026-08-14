{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { 
            # `tree` alternative
            programs.broot = {
                enable = true;
                enableZshIntegration = true;
                enableBashIntegration = true;
                enableFishIntegration = true;
            };
        };
}
