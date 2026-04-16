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
        # # description = "nixd lsp";
        home.packages = with pkgs; [
          nixd
        ];
      };
  };
  ${aspectChain} = den.lib.perHost {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          nixd
        ];
      };
  };
}

