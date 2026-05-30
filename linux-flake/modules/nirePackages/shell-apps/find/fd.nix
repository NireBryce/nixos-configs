{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.homeManager.${moduleName} = {
            # # description = "`find` alternative";
            home.packages = with pkgs; [
                fd
            ];
        };
    };
}
