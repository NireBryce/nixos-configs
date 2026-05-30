{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "system call tracer https://linux.die.net/man/1/strace";
            home.packages = with pkgs; [
                strace
            ];
        };
    };
}
