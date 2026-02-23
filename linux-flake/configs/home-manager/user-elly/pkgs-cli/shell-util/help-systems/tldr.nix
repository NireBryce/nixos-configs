# tldr - community provided man pages
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    tldr
];
in
{
    home.packages = packageList;
}
;}
