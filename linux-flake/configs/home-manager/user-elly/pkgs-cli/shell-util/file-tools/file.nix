# desc = "show filetype";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    file
];
in
{
    home.packages = packageList;
}
;}
