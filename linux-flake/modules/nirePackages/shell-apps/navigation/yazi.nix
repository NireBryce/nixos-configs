{ 
    perSystem = {lib, pkgs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { 
            # # description = "yazi - file browser";
            home.packages = with pkgs; [
                yazi
            ];
        };
    };
}
