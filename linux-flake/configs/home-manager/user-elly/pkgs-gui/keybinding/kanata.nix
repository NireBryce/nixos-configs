# kanata - input-level keybinding, platform independent
{ den.aspects.hm.provides.pkgs-gui = 
{ pkgs, ... }:
let packageList = with pkgs; [
    kanata
];
in
{
    home.packages = packageList;
}
;}
