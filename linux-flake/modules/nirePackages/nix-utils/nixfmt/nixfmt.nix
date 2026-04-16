{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perHost {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "nixfmt - .nix file formatter";
      home.packages = with pkgs; [
        nixfmt
      ];
    };
  };
  ${aspectChain} = den.lib.perHost {
    nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        nixfmt
      ];
    };
  };
}
