# desc = "fselect - I don't remember what this does"; # TODO: better desc
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    fselect
];
in
{
    home.packages = packageList;
}
;}
