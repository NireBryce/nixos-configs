{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.qpwgraph ];

    flake.modules.homeManager.qpwgraph =
# desc = "qpw graph virtual mixer";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        qpwgraph
    ];
}
;}
