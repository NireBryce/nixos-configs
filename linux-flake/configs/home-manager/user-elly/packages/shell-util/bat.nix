# desc = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
{ flake.modules.homeManager.packages.shellUtil.bat =
{ pkgs, ... }:
let packageList = with pkgs; [
    bat
];
in
{
    home.packages = packageList;
}
;}
