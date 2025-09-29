# desc = "terminal markdown viewer https://github.com/charmbracelet/glow";
{ pkgs, ... }:
let packageList = with pkgs; [
    glow
];
in
{
    home.packages = packageList;
}
