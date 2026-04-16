{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "nixfmt - .nix file formatter";
      home.packages = with pkgs; [
        nixfmt
      ];
    };
  };
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        nixfmt
      ];
    };
  };
}
