{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "nix-store analysis";
            home.packages = with pkgs; [
                nix-du
            ];
        };
    };
}
