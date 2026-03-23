# aria2 -cli download manager
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        aria2
    ];
}
