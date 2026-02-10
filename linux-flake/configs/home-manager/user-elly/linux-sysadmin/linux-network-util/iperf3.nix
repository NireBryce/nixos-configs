# desc = "network tools https://software.es.net/iperf/";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    iperf3
];
in
{
    home.packages = packageList;
}
;}
