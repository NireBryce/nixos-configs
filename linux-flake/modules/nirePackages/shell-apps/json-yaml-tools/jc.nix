{ 
    perSystem = {lib, pkgs, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
            home.packages = with pkgs; [
                jc
            ];
        };
    };
}
