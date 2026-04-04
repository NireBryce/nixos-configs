{ pkgs, ... }:
{
# network scanner http://www.nmap.org/
    home.packages = with pkgs; [
        nmap
    ];
}
