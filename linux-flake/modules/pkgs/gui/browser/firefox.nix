{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.firefox ];

    flake.modules.homeManager.firefox =
# desc = "  ";
{ pkgs, ... }:
{
    # todo: this is also installed as a system package, does that matter?
    home.packages = with pkgs; [ firefox ];
}
;}
