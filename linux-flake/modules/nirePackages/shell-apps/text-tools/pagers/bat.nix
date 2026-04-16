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
      # # description = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
      home.packages = with pkgs; [
        bat
      ];
    };
  };
}
