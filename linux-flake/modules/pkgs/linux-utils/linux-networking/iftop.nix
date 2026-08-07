{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.iftop ];

    flake.modules.homeManager.iftop =
# desc = "network monitor https://pdw.ex-parrot.com/iftop/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        iftop
    ];
}
;}
