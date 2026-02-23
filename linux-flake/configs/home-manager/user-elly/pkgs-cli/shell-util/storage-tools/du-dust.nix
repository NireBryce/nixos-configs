# desc = "`du` alternative";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    dust
];
in
{
    home.packages = packageList;
}
;}
