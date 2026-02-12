# desc = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    bat
];
in
{
    home.packages = packageList;
}
;}
