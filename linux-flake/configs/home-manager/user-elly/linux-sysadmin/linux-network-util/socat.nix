# desc = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    socat
];
in
{
    home.packages = packageList;
}
;}
