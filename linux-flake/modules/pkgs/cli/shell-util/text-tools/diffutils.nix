{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.diffutils ];

    flake.modules.homeManager.diffutils =
# desc = "`diff` utils";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        diffutils
    ];
}
;}
