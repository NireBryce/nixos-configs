{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  {
        # # description = "provides `dig` + `nslookup`";
        home.packages = with pkgs; [
            dnsutils
        ];
    };
}
