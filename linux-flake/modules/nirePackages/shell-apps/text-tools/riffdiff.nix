{ 
    perSystem = {lib, pkgs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { 
            # # description = "per-character in-line diff";
            home.packages = with pkgs; [
                riffdiff
            ];
        };
    };
}
