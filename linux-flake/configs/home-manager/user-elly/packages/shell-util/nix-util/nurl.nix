# desc = "make nix fetcher calls from repository URLs";
{ flake.modules.homeManager.packages.nix.nurl =
{ pkgs, ... }:
let packageList = with pkgs; [
    nurl
];
in
{
    home.packages = packageList;
}
;}
