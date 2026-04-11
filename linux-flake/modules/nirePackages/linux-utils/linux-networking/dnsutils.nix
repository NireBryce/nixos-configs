{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager =  {
        # description = "provides `dig` + `nslookup`";
        home.packages = with pkgs; [
            dnsutils
        ];
    };
}
