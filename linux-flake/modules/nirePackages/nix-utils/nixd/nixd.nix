{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        # # description = "nixd lsp";
        home.packages = with pkgs; [
          nixd
        ];
      };
  };
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          nixd
        ];
      };
  };
}

