# desc = "`htop` alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        btop
    ];
}
