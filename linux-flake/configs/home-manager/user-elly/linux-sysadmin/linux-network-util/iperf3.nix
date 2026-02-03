# desc = "network tools https://software.es.net/iperf/";
{ flake.modules.homeManager.commonLinux.networkUtil.iperf3 =
{ pkgs, ... }:
let packageList = with pkgs; [
    iperf3
];
in
{
    home.packages = packageList;
}
;}
