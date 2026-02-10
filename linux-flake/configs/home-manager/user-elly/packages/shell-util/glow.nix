# desc = "terminal markdown viewer https://github.com/charmbracelet/glow";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    glow
];
in
{
    home.packages = packageList;
}
;}
