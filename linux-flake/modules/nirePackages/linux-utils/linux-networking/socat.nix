{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # # description = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
      home.packages = with pkgs; [
        socat
      ];
    };
}
