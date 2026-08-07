{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.wget ];

    flake.modules.homeManager.wget =
# desc = "its like curl but different https://www.gnu.org/software/wget/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        wget
    ];
}
;}
