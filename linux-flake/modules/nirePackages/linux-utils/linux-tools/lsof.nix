{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager =  {
        # description = "list open files https://linux.die.net/man/1/lsof";
        home.packages = with pkgs; [
            lsof
        ];
    };
}

