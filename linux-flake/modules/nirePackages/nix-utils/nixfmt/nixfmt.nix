{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "nixfmt - .nix file formatter";
        home.packages = with pkgs; [
            nixfmt
            nixpkgs-fmt
        ];
    };
}
