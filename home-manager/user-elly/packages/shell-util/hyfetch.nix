# desc = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
{ pkgs, ... }:
let packageList = with pkgs; [
    hyfetch
];
in
{
    home.packages = packageList;
}
