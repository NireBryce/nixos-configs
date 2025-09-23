# desc = "qpw graph virtual mixer";
{ pkgs, ... }:
let
    packageList = with pkgs; [
        qpwgraph
    ];
in 
{
    home.packages = packageList;
}
