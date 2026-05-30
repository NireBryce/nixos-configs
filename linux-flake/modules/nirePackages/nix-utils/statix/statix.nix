{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
        # # description = "nix antipattern linter";
            home.packages = with pkgs; [
                statix
            ];
        };
    };
}
