# github-desktop - github gui 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        github-desktop
    ];
}
