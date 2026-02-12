# desc = "count lines of code";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    tokei
];
in
{
    home.packages = packageList;
}
;}
