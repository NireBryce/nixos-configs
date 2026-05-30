{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "list open files https://linux.die.net/man/1/lsof";
            home.packages = with pkgs; [
                lsof
            ];
        };
    };
}
