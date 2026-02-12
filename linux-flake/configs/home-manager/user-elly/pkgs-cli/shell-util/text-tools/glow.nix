# desc = "terminal markdown viewer https://github.com/charmbracelet/glow";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    glow
];
in
{
    home.packages = packageList;
}
;}
