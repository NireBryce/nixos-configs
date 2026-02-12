# desc = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    hyfetch
];
in
{
    home.packages = packageList;
}
;}
