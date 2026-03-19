# desc = "qpw graph virtual mixer";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        qpwgraph
    ];
}
