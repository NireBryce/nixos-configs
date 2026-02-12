# desc = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    hyfetch
];
in
{
    home.packages = packageList;
}
;}
