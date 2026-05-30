{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
        # description =  "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
            home.packages = with pkgs; [
                mtr
            ];
        };
    };
}
