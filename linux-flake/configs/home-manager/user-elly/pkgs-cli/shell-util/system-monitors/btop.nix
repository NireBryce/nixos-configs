# desc = "`htop` alternative";
{ ... }:
{ den.aspects.pkgs-cli.homeManager =
{ pkgs, ... }:
let packageList = with pkgs; [
    btop
];
in
{
    home.packages = packageList;
}
;}
