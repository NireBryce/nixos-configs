{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            #  # description = "scan for 'dead' (uncalled) nix code";
            home.packages = with pkgs; [
                deadnix
            ];
        };
    };
}
