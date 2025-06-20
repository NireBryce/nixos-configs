# desc = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
{ pkgs, ... }:
let packageList = with pkgs; [
    bat
];
in
{
    home.packages = packageList;
}
