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
      # # description = "nixfmt - .nix file formatter";
      home.packages = with pkgs; [
        nixfmt
      ];
    };
  };
  nixos = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      nixfmt
    ];
  };
}
