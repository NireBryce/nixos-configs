# desc = "network tools https://software.es.net/iperf/";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    iperf3
];
in
{
    home.packages = packageList;
}
;}
