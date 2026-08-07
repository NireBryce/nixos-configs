{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.bat ];

    flake.modules.homeManager.bat =
# desc = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        bat
    ];
}
;}
