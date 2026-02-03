# desc = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
{ flake.modules.homeManager.commonLinux.networkUtil.socat =
{ pkgs, ... }:
let packageList = with pkgs; [
    socat
];
in
{
    home.packages = packageList;
}
;}
