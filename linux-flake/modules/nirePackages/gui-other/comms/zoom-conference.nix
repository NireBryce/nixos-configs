{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
        # description = "zoom videoconferencing software";
            home.packages = with pkgs; [
                zoom-us
            ];
        };
    };
}
