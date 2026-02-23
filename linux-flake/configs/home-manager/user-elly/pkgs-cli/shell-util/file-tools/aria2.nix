# aria2 -cli download manager
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    aria2
];
in
{
    home.packages = packageList;
}
;}
