{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.chrome ];

    flake.modules.homeManager.chrome =
# desc = "  ";
{ pkgs, ... }:
{
    # todo: this is also installed as a system package, does that matter?
    home.packages = with pkgs; [ google-chrome ];
}
;}
