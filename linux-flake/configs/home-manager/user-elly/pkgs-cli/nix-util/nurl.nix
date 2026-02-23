# desc = "make nix fetcher calls from repository URLs";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nurl
];
in
{
    home.packages = packageList;
}
;}
