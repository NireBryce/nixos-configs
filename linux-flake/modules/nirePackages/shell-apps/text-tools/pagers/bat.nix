{ 
    perSystem = {lib, pkgs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { 
            # # description = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
            home.packages = with pkgs; [
                bat
            ];
        };
    };
}
