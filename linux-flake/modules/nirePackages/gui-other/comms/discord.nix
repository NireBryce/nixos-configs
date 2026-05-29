{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.homeManager.${moduleName} = {
            # # description = "discord gamer chat app that broke containment";
            home.packages = with pkgs; [
                discord
            ];
        };
    };
}
