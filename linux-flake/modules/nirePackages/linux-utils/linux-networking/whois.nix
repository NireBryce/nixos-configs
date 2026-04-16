{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "whois lookup https://packages.qa.debian.org/w/whois.html";
      home.packages = with pkgs; [
        whois
      ];
    };};
}
