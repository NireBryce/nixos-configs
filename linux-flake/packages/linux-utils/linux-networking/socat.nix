{ pkgs, ... }:
{
# openbsd netcat replacement https://www.dest-unreach.org/socat/
    home.packages  = with pkgs; [
        socat
    ];
}
