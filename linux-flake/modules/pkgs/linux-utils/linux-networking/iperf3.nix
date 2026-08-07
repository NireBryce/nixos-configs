{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.iperf3 ];

    flake.modules.homeManager.iperf3 =
# desc = "network tools https://software.es.net/iperf/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        iperf3
    ];
}
;}
