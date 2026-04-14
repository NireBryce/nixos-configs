{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  { pkgs, ... }: {
        # # description = "system call tracer https://linux.die.net/man/1/strace";
        home.packages = with pkgs; [
            strace
        ];
    };
}
