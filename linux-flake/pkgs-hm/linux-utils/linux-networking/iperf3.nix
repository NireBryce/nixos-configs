# desc = "network tools https://software.es.net/iperf/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        iperf3
    ];
}
