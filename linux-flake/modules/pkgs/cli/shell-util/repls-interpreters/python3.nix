{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.python3 ];

    flake.modules.homeManager.python3 =
# desc = "home-manager instance of python3";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        python3
    ];
}
;}
