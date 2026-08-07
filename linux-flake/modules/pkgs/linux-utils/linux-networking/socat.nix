{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.socat ];

    flake.modules.homeManager.socat =
# desc = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
{ pkgs, ... }:
{
    home.packages  = with pkgs; [
        socat
    ];
}
;}
