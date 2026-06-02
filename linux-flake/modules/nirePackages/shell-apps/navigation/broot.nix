{ 
    perSystem = {lib, pkgs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { 
            # # description = "`tree` alternative";
            programs.broot = {
                enable = true;
                enableZshIntegration = true;
                enableBashIntegration = true;
                enableFishIntegration = true;
            };
        };
    };
}
