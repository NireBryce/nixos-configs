# desc = "fselect - I don't remember what this does"; # TODO: better desc
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        fselect
    ];
}
