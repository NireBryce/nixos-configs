# desc = "terminal markdown viewer https://github.com/charmbracelet/glow";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        glow
    ];
}
