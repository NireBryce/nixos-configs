# desc = "nix man pages, kinda";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    manix
];
in
{
    home.packages = packageList;
}
;}
