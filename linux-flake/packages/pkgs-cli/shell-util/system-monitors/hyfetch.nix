# desc = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        hyfetch
    ];
}
