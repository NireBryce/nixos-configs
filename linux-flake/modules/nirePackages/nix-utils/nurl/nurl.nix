{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
        # # description = "make nix fetcher calls from repository URLs";
            home.packages = with pkgs; [
                nurl
            ];
        };
    };
}
