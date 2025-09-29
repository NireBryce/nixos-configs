# desc = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
{ pkgs, ... }:
let packageList = with pkgs; [
    socat
];
in
{
    home.packages = packageList;
}
