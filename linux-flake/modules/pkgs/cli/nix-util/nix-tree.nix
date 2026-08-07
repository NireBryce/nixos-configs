{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nix-tree ];

    flake.modules.homeManager.nix-tree =
# desc = "view dependency graph";
{ pkgs, ... }:
{
home.packages = with pkgs; [
    nix-tree
];
}
;}
