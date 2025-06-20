# desc = "network tools https://software.es.net/iperf/";
{ pkgs, ... }:
let packageList = with pkgs; [
    iperf3
];
in
{
    home.packages = packageList;
}
