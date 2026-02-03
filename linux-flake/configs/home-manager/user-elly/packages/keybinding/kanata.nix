# kanata - input-level keybinding, platform independent
{ flake.modules.homeManager.packages.keybinding.kanata =
{ pkgs, ... }:
let packageList = with pkgs; [
    kanata
];
in
{
    home.packages = packageList;
}
;}
