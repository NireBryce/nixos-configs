{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
        # # description = "network scanner http://www.nmap.org/";
            home.packages = with pkgs; [
                nmap
            ];
        };
    };
}
