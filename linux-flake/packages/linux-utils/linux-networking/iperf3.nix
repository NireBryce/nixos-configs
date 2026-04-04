{ pkgs, ... }:
{
    home.packages = with pkgs; [
        # network tools https://software.es.net/iperf/
        iperf3
    ];
}
