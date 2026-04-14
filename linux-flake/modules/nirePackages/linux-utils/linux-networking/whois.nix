{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  {
        # # description = "whois lookup https://packages.qa.debian.org/w/whois.html";
        home.packages = with pkgs; [
            whois
        ];
    };
}
