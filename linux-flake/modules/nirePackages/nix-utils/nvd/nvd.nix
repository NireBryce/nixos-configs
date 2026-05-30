{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "nix package version diff";
            home.packages = with pkgs; [
                nvd
            ];
        };
    };
}
