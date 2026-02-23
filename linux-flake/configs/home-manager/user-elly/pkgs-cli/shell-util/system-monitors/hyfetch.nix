# desc = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    hyfetch
];
in
{
    home.packages = packageList;
}
;}
