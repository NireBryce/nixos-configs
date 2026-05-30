{ 
    perSystem = {lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.homeManager.${moduleName} = {
            programs.direnv = {
                enable = true;
                enableBashIntegration = true;
                enableZshIntegration = true;
                enableNushellIntegration = true;
                nix-direnv.enable = true;
            };
        };
    };
}
