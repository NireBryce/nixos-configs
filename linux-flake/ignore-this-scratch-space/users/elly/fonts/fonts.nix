# TODO: duplicated in system fonts, is this for non-nix hosts? consider moving to there
# description = "font packages that are per-user through home-manager";
{ elly.fonts.homeManager = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.iosevka
        nerd-fonts.jetbrains-mono
    ];
}
;}
