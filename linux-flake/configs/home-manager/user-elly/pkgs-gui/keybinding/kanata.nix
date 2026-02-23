# kanata - input-level keybinding, platform independent
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    kanata
];
in
{
    home.packages = packageList;
}
;}
