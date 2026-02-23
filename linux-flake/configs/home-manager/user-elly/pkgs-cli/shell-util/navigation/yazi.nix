# yazi - file browser MAKE BETTER DESC
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    yazi
];
in
{
    home.packages = packageList;
}
;}
