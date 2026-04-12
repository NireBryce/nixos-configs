{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # description = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
        home.packages = with pkgs; [
            jc
        ];
    };
}
