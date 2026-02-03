# desc = "qpw graph virtual mixer";
{ flake.modules.homeManager.packages.audio = 
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
