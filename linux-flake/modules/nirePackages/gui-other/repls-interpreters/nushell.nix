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
      # nushell - the next generation shell
      # hint: nushell -c for tabular display in any shell
      home.packages = with pkgs; [
        nushell
      ];
    };
  };
}
