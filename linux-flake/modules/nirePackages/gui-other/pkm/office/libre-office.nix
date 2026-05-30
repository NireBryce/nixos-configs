{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "libreoffice - office productivity software https://www.libreoffice.org/";
            home.packages = with pkgs; [
                libreoffice-qt
            ];
        };
    };
}
