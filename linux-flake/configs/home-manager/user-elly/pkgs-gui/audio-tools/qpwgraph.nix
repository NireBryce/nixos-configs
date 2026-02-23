# desc = "qpw graph virtual mixer";
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
let
    packageList = with pkgs; [
        qpwgraph
    ];
in 
{
    home.packages = packageList;
}
;}
