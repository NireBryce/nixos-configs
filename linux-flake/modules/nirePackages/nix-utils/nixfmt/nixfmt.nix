{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # # description = "nixfmt - .nix file formatter";
      home.packages = with pkgs; [
        nixfmt
        nixpkgs-fmt
      ];
    };
}
