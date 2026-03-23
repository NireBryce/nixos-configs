# desc = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
{ pkgs, ... }:
{
    home.packages  = with pkgs; [
        socat
    ];
}
