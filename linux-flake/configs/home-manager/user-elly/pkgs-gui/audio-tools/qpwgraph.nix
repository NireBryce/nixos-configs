# desc = "qpw graph virtual mixer";
{ den.aspects.hm.provides.pkgs-gui = 
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
