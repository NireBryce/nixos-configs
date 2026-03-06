# desc = "`du` alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        dust
    ];
}
