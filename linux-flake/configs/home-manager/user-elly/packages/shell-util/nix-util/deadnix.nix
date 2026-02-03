# desc = "scan for 'dead' (uncalled) nix code";
{ flake.modules.homeManager.packages.nix.deadnix =
{ pkgs, ... }:
let packageList = with pkgs; [
    deadnix
];
in
{
    home.packages = packageList;
}
;}
