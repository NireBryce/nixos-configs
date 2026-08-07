{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.sysstat ];

    flake.modules.homeManager.sysstat =
# desc = "system stats http://sebastien.godard.pagesperso-orange.fr/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        sysstat
    ];
}
;}
