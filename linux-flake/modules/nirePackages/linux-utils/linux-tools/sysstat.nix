{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "system stats http://sebastien.godard.pagesperso-orange.fr/";
            home.packages = with pkgs; [
                sysstat
            ];
        };
    };
}
