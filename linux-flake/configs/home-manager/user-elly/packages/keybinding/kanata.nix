# desc = "input-level keybinding, platform independent";
{ pkgs, ... }:
let packageList = with pkgs; [
    kanata
];
in
{
    home.packages = packageList;
}
