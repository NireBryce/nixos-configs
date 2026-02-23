# desc = "count lines of code";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    tokei
];
in
{
    home.packages = packageList;
}
;}
