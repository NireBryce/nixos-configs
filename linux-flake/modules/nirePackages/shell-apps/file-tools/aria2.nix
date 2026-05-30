{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "aria2 -cli download manager";
            home.packages = with pkgs; [
                aria2
            ];
        };
    };
}
