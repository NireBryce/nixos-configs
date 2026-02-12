# desc = "fselect - I don't remember what this does"; # TODO: better desc
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    fselect
];
in
{
    home.packages = packageList;
}
;}
