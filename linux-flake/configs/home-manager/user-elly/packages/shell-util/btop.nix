# desc = "`htop` alternative";
{ pkgs, ... }:
{ flake.modules.homeManager.packages.shellUtil.btop =
let packageList = with pkgs; [
    btop
];
in
{
    home.packages = packageList;
}
;}
