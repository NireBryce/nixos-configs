{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName} = {
    homeManager =
      { pkgs, ... }:
      {
        # # description = "nixd lsp";
        home.packages = with pkgs; [
          nixd
        ];
      };
  };
  nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        nixd
      ];
    };
}
