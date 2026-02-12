# tldr - community provided man pages
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    tldr
];
in
{
    home.packages = packageList;
}
;}
