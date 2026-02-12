# desc = "qpw graph virtual mixer";
{ den.bundles.hm.audio-tools =  
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
