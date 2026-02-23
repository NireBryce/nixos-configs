# desc = "`rg` much faster grep alternative";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ripgrep
];
in
{
    home.packages = packageList;
}
;}
