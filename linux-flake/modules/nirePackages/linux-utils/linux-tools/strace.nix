{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.linux-utils._.${moduleName}.homeManager =  {
        # description = "system call tracer https://linux.die.net/man/1/strace";
        home.packages = with pkgs; [
            strace
        ];
    };
}
