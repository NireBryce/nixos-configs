# desc = "per-character in-line diff";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    riffdiff
];
in
{
    home.packages = packageList;
}
;}
