{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  {
        # description = "library call tracer https://linux.die.net/man/1/ltrace";
        home.packages = with pkgs; [
            ltrace
        ];
    };
}
