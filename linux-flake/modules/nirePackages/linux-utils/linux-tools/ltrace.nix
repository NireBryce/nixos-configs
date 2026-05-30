{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "library call tracer https://linux.die.net/man/1/ltrace";
            home.packages = with pkgs; [
                ltrace
            ];
        };
    };
}
