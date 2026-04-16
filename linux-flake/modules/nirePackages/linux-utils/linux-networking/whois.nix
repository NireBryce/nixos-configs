{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "whois lookup https://packages.qa.debian.org/w/whois.html";
      home.packages = with pkgs; [
        whois
      ];
    };};
}
