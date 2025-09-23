# desc = "fselect - I don't remember what this does"; # TODO: better desc
{ pkgs, ... }:
let packageList = with pkgs; [
    fselect
];
in
{
    home.packages = packageList;
}
