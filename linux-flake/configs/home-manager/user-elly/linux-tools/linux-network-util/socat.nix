# desc = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    socat
];
in
{
    home.packages = packageList;
}
;}
