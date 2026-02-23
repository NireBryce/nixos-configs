# delta - a better git diff viewer
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    delta
];
in
{
    home.packages = packageList;
}
;}
