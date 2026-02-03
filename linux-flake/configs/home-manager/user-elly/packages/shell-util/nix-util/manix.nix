# desc = "nix man pages, kinda";
{ flake.modules.homeManager.packages.nix.manix =
{ pkgs, ... }:
let packageList = with pkgs; [
    manix
];
in
{
    home.packages = packageList;
}
;}
