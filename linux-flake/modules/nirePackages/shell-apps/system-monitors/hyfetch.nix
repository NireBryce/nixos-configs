{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # # description = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
      home.packages = with pkgs; [
        hyfetch
      ];
    };
}
