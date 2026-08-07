{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nixfmt ];

    flake.modules.homeManager.nixfmt =
# nixfmt - .nix file formatter";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nixfmt
        nixpkgs-fmt
    ];
}
;}
