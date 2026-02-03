# desc = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
{ flake.modules.homeManager.packages.shellUtil.hyfetch =
{ pkgs, ... }:
let packageList = with pkgs; [
    hyfetch
];
in
{
    home.packages = packageList;
}
;}
