{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  { pkgs, ... }: {
        # # description = "list open files https://linux.die.net/man/1/lsof";
        home.packages = with pkgs; [
            lsof
        ];
    };
}

