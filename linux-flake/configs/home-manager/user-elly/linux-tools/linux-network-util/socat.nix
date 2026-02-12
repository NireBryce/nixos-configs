# desc = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    socat
];
in
{
    home.packages = packageList;
}
;}
