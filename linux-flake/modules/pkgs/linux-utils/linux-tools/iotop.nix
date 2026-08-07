{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.iotop ];

    flake.modules.homeManager.iotop =
# iotop -io monitoring http://guichaz.free.fr/iotop";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        iotop
    ];
}
;}
