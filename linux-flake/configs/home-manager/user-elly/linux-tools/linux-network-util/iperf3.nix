# desc = "network tools https://software.es.net/iperf/";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    iperf3
];
in
{
    home.packages = packageList;
}
;}
