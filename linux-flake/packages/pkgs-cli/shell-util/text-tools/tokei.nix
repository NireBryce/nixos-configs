# desc = "count lines of code";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        tokei
    ];
}
