{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "just - justfile runner";
            home.file = {
                "./.justfile".source = ./config/.justfile;
                "./.just/.justfile".source = ./config/.justfile;
                "./.just".source = ./config;
            };

            home.packages = with pkgs; [
                just
            ];
        };
    };
}
