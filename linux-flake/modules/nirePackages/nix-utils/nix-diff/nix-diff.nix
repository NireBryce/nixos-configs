{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "diff nix code";
            home.packages = with pkgs; [
                nix-diff
            ];
        };
    };
}
